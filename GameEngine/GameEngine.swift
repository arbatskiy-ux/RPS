import Foundation
import Combine

/// Orchestrates game logic, syncs state with peers, and triggers device feedback.
final class GameEngine: ObservableObject {

    @Published private(set) var phase: GamePhase = .idle
    @Published private(set) var state: GameState = GameState()
    let roundTimer = RoundTimer(duration: 60)

    private let session: MultipeerSession
    private let hapticManager: HapticManager
    private var cancellables = Set<AnyCancellable>()

    init(session: MultipeerSession, hapticManager: HapticManager) {
        self.session = session
        self.hapticManager = hapticManager
        subscribeToNetwork()
        subscribeToTimer()
    }

    // MARK: - Public API

    func startGame() {
        guard session.connectedPeers.isEmpty == false else { return }
        phase = .playing
        state = GameState()
        roundTimer.start()
        broadcast(.gameStarted)
    }

    func endGame() {
        roundTimer.stop()
        phase = .results
        broadcast(.gameEnded)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.phase = .idle
        }
    }

    func handlePlayerAction(_ action: PlayerAction) {
        process(action: action, from: session.localPeerID.displayName)
        broadcast(.playerAction(action))
    }

    /// Called by MotionManager when a shake is detected.
    func handleShake() {
        handlePlayerAction(.shake)
    }

    // MARK: - Private

    private func subscribeToTimer() {
        roundTimer.onFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.endGame() }
            .store(in: &cancellables)
    }

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
        case .gameStarted:
            phase = .playing
        case .gameEnded:
            phase = .idle
        case .playerAction(let action):
            process(action: action, from: message.senderName)
        case .stateSync(let syncedState):
            state = syncedState
        }
    }

    private func process(action: PlayerAction, from playerName: String) {
        switch action {
        case .tap:
            state.scores[playerName, default: 0] += 1
            hapticManager.playImpact(style: .medium)
        case .shake:
            state.scores[playerName, default: 0] += 3
            hapticManager.playNotification(type: .success)
        }
    }

    private func broadcast(_ payload: GameMessage.Payload) {
        let message = GameMessage(senderName: session.localPeerID.displayName, payload: payload)
        session.send(message: message)
    }
}
