import SwiftUI
import Combine

/// Global application state shared across the entire app.
final class AppState: ObservableObject {
    enum Screen {
        case home          // Home Screen — main menu
        case connection    // Connection Screen — find/connect players
        case game          // Game Screen — countdown, choosing, reveal
        case results       // Result Screen — match winner + history
    }

    @Published var currentScreen: Screen = .home
    @Published var playerName: String = UIDevice.current.name

    let session: MultipeerSession
    let gameEngine: GameEngine
    let hapticManager: HapticManager
    let motionManager: MotionManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        let session = MultipeerSession(displayName: UIDevice.current.name)
        let hapticManager = HapticManager()
        let motionManager = MotionManager()
        let gameEngine = GameEngine(session: session, hapticManager: hapticManager)

        self.session = session
        self.gameEngine = gameEngine
        self.hapticManager = hapticManager
        self.motionManager = motionManager

        bindGameEngine()
    }

    private func bindGameEngine() {
        gameEngine.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                switch phase {
                case .shakeReady, .countdown, .choosing, .reveal:
                    self?.currentScreen = .game
                case .matchResult:
                    self?.currentScreen = .results
                case .idle:
                    // Go to connection screen if connected, home if not
                    if self?.session.isConnected == true {
                        self?.currentScreen = .connection
                    } else {
                        self?.currentScreen = .home
                    }
                }
            }
            .store(in: &cancellables)
    }

    func goToConnection() {
        currentScreen = .connection
    }

    func goToHome() {
        session.disconnect()
        currentScreen = .home
    }
}
