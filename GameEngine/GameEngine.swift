import Foundation
import Combine

/// Orchestrates Rock-Paper-Scissors.
/// The HOST is the single source of truth: it runs the round loop, generates random moves
/// using a secure RNG, collects choices, determines winners, and syncs results to the GUEST.
final class GameEngine: ObservableObject {

    @Published private(set) var phase: GamePhase = .idle
    @Published private(set) var state: GameState = GameState()
    @Published private(set) var countdownValue: Int = 3
    @Published private(set) var countdownLabel: String = ""
    @Published private(set) var choiceTimeRemaining: Int = 5

    /// Set once the local player makes a choice this round. Reset each round.
    @Published private(set) var localChoice: RPSChoice?

    let roundTimer = RoundTimer(duration: 5)

    private let session: MultipeerSession
    let hapticManager: HapticManager
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: AnyCancellable?

    // HOST-only: collected choices for the current round
    private var hostChoice: RPSChoice?
    private var guestChoice: RPSChoice?

    // Shake mode: HOST waits for both players to shake 3 times
    private var hostShakeReady = false
    private var guestShakeReady = false

    var isHost: Bool { session.isHost }

    init(session: MultipeerSession, hapticManager: HapticManager) {
        self.session = session
        self.hapticManager = hapticManager
        subscribeToNetwork()
        subscribeToChoiceTimer()
        subscribeToDisconnect()
    }

    // MARK: - Public API

    /// HOST only: begins the match.
    func startGame(shakeMode: Bool = false) {
        guard isHost, !session.connectedPeers.isEmpty else { return }

        state = GameState()
        state.hostName = session.localPeerID.displayName
        state.guestName = session.connectedPeers.first?.displayName ?? "Guest"
        state.isShakeModeEnabled = shakeMode

        broadcast(.gameStarted(state))

        if shakeMode {
            enterShakePhase()
        } else {
            startRound()
        }
    }

    /// Both: player picks Rock, Paper, or Scissors.
    func choose(_ choice: RPSChoice) {
        guard phase == .choosing, localChoice == nil else { return }
        localChoice = choice
        hapticManager.playImpact(style: .medium)

        if isHost {
            hostChoice = choice
            tryResolveRound()
        } else {
            broadcast(.playerChoice(choice))
        }
    }

    /// Abort the match (leave button).
    func endGame() {
        roundTimer.stop()
        countdownTimer?.cancel()
        phase = .idle
        if isHost {
            broadcast(.matchEnded(state))
        }
    }

    /// Called by shake mode when the local player has completed 3 shakes.
    func localPlayerShakeReady() {
        if isHost {
            hostShakeReady = true
            tryStartAfterShakes()
        } else {
            broadcast(.playerShakeReady)
        }
    }

    // MARK: - Shake Mode

    private func enterShakePhase() {
        phase = .shakeReady
        hostShakeReady = false
        guestShakeReady = false
        if isHost {
            broadcast(.shakePhaseStarted)
        }
    }

    private func tryStartAfterShakes() {
        guard isHost, hostShakeReady, guestShakeReady else { return }
        broadcast(.shakePhaseCompleted)
        startRound()
    }

    // MARK: - Round Flow (HOST drives this)

    /// Starts the "Rock / Paper / Scissors" countdown, then opens the choosing phase.
    private func startRound() {
        guard isHost else { return }

        // Reset per-round state
        hostChoice = nil
        guestChoice = nil
        localChoice = nil

        runCountdown { [weak self] in
            self?.beginChoosing()
        }
    }

    private func beginChoosing() {
        phase = .choosing
        choiceTimeRemaining = 5
        roundTimer.start()

        if isHost {
            broadcast(.startChoosing)
        }
    }

    /// HOST: called when the 5s choice timer expires.
    /// Assigns a secure random choice to anyone who didn't pick.
    private func choiceTimerExpired() {
        guard isHost, phase == .choosing else { return }

        if hostChoice == nil {
            hostChoice = RPSChoice.secureRandom()
            localChoice = hostChoice
        }
        if guestChoice == nil {
            guestChoice = RPSChoice.secureRandom()
        }
        resolveRound()
    }

    /// HOST: check if both players have chosen; if so, resolve immediately.
    private func tryResolveRound() {
        guard isHost, hostChoice != nil, guestChoice != nil else { return }
        roundTimer.stop()
        resolveRound()
    }

    /// HOST: determine winner, broadcast result, trigger haptics, advance state.
    private func resolveRound() {
        guard isHost, let hc = hostChoice, let gc = guestChoice else { return }

        let result = RoundResult.determine(
            round: state.currentRound,
            hostChoice: hc,
            guestChoice: gc,
            hostName: state.hostName,
            guestName: state.guestName
        )

        // Update wins
        if result.winnerName == state.hostName {
            state.hostWins += 1
        } else if result.winnerName == state.guestName {
            state.guestWins += 1
        }

        state.roundResults.append(result)

        // Show reveal phase
        phase = .reveal(result)
        broadcast(.roundResult(result))
        broadcast(.stateSync(state))

        // Haptic: winner gets light tap, loser gets 4x strong pattern
        playRoundResultHaptics(result: result, localName: state.hostName)

        // After reveal delay, either next round or match end
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.afterReveal(result: result)
        }
    }

    private func afterReveal(result: RoundResult) {
        guard isHost else { return }

        if state.isMatchOver {
            phase = .matchResult
            broadcast(.matchEnded(state))
            // Final haptic for match result
            if state.matchWinner == state.hostName {
                hapticManager.playWinnerFeedback()
            } else {
                hapticManager.playLoserFeedback()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.phase = .idle
            }
        } else {
            // If draw, don't advance round number
            if result.winnerName != nil {
                state.currentRound += 1
            }

            if state.isShakeModeEnabled {
                enterShakePhase()
            } else {
                startRound()
            }
        }
    }

    // MARK: - Haptic Patterns

    private func playRoundResultHaptics(result: RoundResult, localName: String) {
        if result.winnerName == nil {
            // Draw — neutral feedback
            hapticManager.playImpact(style: .medium)
        } else if result.winnerName == localName {
            hapticManager.playWinnerFeedback()
        } else {
            hapticManager.playLoserFeedback()
        }
    }

    // MARK: - Countdown ("Rock... Paper... Scissors!")

    private func runCountdown(completion: @escaping () -> Void) {
        countdownValue = 3
        countdownLabel = CountdownLabel.forTick(3).rawValue
        phase = .countdown(3)
        localChoice = nil
        hapticManager.playCountdownPulse()
        broadcast(.roundCountdown(3))

        var remaining = 3
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                remaining -= 1
                if remaining > 0 {
                    self?.countdownValue = remaining
                    self?.countdownLabel = CountdownLabel.forTick(remaining).rawValue
                    self?.phase = .countdown(remaining)
                    self?.broadcast(.roundCountdown(remaining))
                    self?.hapticManager.playCountdownPulse()
                } else {
                    self?.countdownTimer?.cancel()
                    completion()
                }
            }
    }

    // MARK: - Network

    private func subscribeToNetwork() {
        session.receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handle(message: message)
            }
            .store(in: &cancellables)
    }

    private func handle(message: GameMessage) {
        switch message.payload {

        // --- GUEST receives from HOST ---
        case .gameStarted(let initialState):
            if !isHost {
                state = initialState
                localChoice = nil
            }

        case .roundCountdown(let value):
            if !isHost {
                countdownValue = value
                countdownLabel = CountdownLabel.forTick(value).rawValue
                phase = .countdown(value)
                localChoice = nil
                hapticManager.playCountdownPulse()
            }

        case .startChoosing:
            if !isHost {
                phase = .choosing
                choiceTimeRemaining = 5
                roundTimer.start()
            }

        case .roundResult(let result):
            if !isHost {
                roundTimer.stop()
                phase = .reveal(result)
                playRoundResultHaptics(result: result, localName: state.guestName)
            }

        case .matchEnded(let finalState):
            if !isHost {
                state = finalState
                roundTimer.stop()
                phase = .matchResult
                if state.matchWinner == state.guestName {
                    hapticManager.playWinnerFeedback()
                } else {
                    hapticManager.playLoserFeedback()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.phase = .idle
                }
            }

        case .stateSync(let syncedState):
            if !isHost {
                state = syncedState
            }

        case .shakePhaseStarted:
            if !isHost {
                phase = .shakeReady
            }

        case .shakePhaseCompleted:
            if !isHost {
                // HOST will send countdown next
            }

        // --- HOST receives from GUEST ---
        case .playerChoice(let choice):
            if isHost {
                guestChoice = choice
                tryResolveRound()
            }

        case .playerShakeReady:
            if isHost {
                guestShakeReady = true
                tryStartAfterShakes()
            }
        }
    }

    private func subscribeToChoiceTimer() {
        roundTimer.onFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.choiceTimerExpired() }
            .store(in: &cancellables)

        roundTimer.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in self?.choiceTimeRemaining = Int(t) }
            .store(in: &cancellables)
    }

    private func subscribeToDisconnect() {
        session.connectionEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .peerDisconnected = event {
                    guard let self else { return }
                    if self.phase != .idle && self.phase != .matchResult {
                        self.roundTimer.stop()
                        self.countdownTimer?.cancel()
                        self.phase = .idle
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Broadcast

    private func broadcast(_ payload: GameMessage.Payload) {
        let message = GameMessage(senderName: session.localPeerID.displayName, payload: payload)
        session.send(message: message)
    }
}
