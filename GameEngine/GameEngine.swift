import Foundation
import Combine

/// Orchestrates game logic. The HOST is the authoritative source of truth:
/// it generates moves, runs timers, scores actions, and syncs state to GUEST(s).
/// The GUEST only sends player actions and renders state received from the HOST.
final class GameEngine: ObservableObject {

    @Published private(set) var phase: GamePhase = .idle
    @Published private(set) var state: GameState = GameState()
    @Published private(set) var countdownValue: Int = 3
    let roundTimer = RoundTimer(duration: 10) // per-move timer

    private let session: MultipeerSession
    private let hapticManager: HapticManager
    private var cancellables = Set<AnyCancellable>()
    private var moveTimer: AnyCancellable?

    var isHost: Bool { session.isHost }

    init(session: MultipeerSession, hapticManager: HapticManager) {
        self.session = session
        self.hapticManager = hapticManager
        subscribeToNetwork()
        subscribeToTimer()
        subscribeToDisconnect()
    }

    // MARK: - Public API (called from Views)

    /// HOST only: begins the game with a 3-2-1 countdown, then starts the first move.
    func startGame() {
        guard isHost, !session.connectedPeers.isEmpty else { return }

        state = GameState()
        // Initialize scores for all players
        state.scores[session.localPeerID.displayName] = 0
        for peer in session.connectedPeers {
            state.scores[peer.displayName] = 0
        }

        runCountdown { [weak self] in
            self?.phase = .playing
            self?.broadcast(.gameStarted(self!.state))
            self?.nextMove()
        }
    }

    /// Both: report a player action in response to the current move.
    func handlePlayerAction(_ action: PlayerAction) {
        if isHost {
            // HOST scores locally and syncs
            scoreAction(action, from: session.localPeerID.displayName)
            syncState()
        } else {
            // GUEST sends action to HOST for authoritative scoring
            broadcast(.playerAction(action))
        }
        hapticManager.playImpact(style: .medium)
    }

    /// Called by MotionManager when a shake is detected.
    func handleShake() {
        handlePlayerAction(.shake)
    }

    /// HOST only: called when the player holds steady — reports stability score.
    func reportSteadyScore(_ score: Double) {
        handlePlayerAction(.steadyScore(score))
    }

    func endGame() {
        roundTimer.stop()
        moveTimer?.cancel()
        phase = .results
        if isHost {
            broadcast(.gameEnded(state))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.phase = .idle
        }
    }

    // MARK: - HOST: Round Flow

    /// Generates the next random move and broadcasts it to all peers.
    private func nextMove() {
        guard isHost, phase == .playing else { return }

        if state.round > state.totalRounds {
            endGame()
            return
        }

        let move = Move.random()
        state.currentMove = move
        state.timeRemaining = 10
        roundTimer.start()

        broadcast(.newMove(move))
        syncState()
    }

    /// Called when the per-move timer expires. Advances to next round.
    private func moveTimerFinished() {
        guard isHost else { return }
        roundTimer.stop()
        state.round += 1
        state.currentMove = nil

        if state.round > state.totalRounds {
            endGame()
        } else {
            // Brief pause between moves
            phase = .movePause
            syncState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.phase == .movePause else { return }
                self.phase = .playing
                self.nextMove()
            }
        }
    }

    // MARK: - HOST: Scoring

    private func scoreAction(_ action: PlayerAction, from playerName: String) {
        guard isHost, let currentMove = state.currentMove else { return }

        let points: Int
        switch (currentMove.kind, action) {
        case (.tapFast, .tap):
            points = 1
        case (.shakeIt, .shake):
            points = 3
        case (.holdSteady, .steadyScore(let stability)):
            // Lower stability value = steadier = more points
            points = max(1, Int(10 - stability))
        default:
            // Wrong action for this move type — no points
            points = 0
        }

        state.scores[playerName, default: 0] += points
    }

    // MARK: - Countdown

    private func runCountdown(completion: @escaping () -> Void) {
        countdownValue = 3
        phase = .countdown(3)
        broadcast(.roundCountdown(3))

        var remaining = 3
        moveTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                remaining -= 1
                if remaining > 0 {
                    self?.countdownValue = remaining
                    self?.phase = .countdown(remaining)
                    self?.broadcast(.roundCountdown(remaining))
                } else {
                    self?.moveTimer?.cancel()
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
                phase = .playing
            }

        case .gameEnded(let finalState):
            if !isHost {
                state = finalState
                roundTimer.stop()
                phase = .results
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    self?.phase = .idle
                }
            }

        case .roundCountdown(let value):
            if !isHost {
                countdownValue = value
                phase = .countdown(value)
            }

        case .newMove(let move):
            if !isHost {
                state.currentMove = move
                state.timeRemaining = 10
                roundTimer.start()
                phase = .playing
                hapticManager.playNotification(type: .warning)
            }

        case .stateSync(let syncedState):
            if !isHost {
                // Preserve local phase, update data
                let currentPhase = phase
                state = syncedState
                if currentPhase == .playing { phase = .playing }
            }

        // --- HOST receives from GUEST ---
        case .playerAction(let action):
            if isHost {
                scoreAction(action, from: message.senderName)
                syncState()
                hapticManager.playImpact(style: .light)
            }
        }
    }

    private func subscribeToTimer() {
        roundTimer.onFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.moveTimerFinished() }
            .store(in: &cancellables)
    }

    private func subscribeToDisconnect() {
        session.connectionEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .peerDisconnected = event {
                    if self?.phase == .playing || self?.phase == .movePause {
                        self?.endGame()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sync

    /// HOST broadcasts the full authoritative state to all peers.
    private func syncState() {
        guard isHost else { return }
        broadcast(.stateSync(state))
    }

    private func broadcast(_ payload: GameMessage.Payload) {
        let message = GameMessage(senderName: session.localPeerID.displayName, payload: payload)
        session.send(message: message)
    }
}
