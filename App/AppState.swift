import SwiftUI
import Combine

/// Global application state shared across the entire app.
final class AppState: ObservableObject {
    enum Screen {
        case lobby
        case game
        case results
    }

    @Published var currentScreen: Screen = .lobby
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
                case .countdown, .choosing, .reveal:
                    self?.currentScreen = .game
                case .matchResult:
                    self?.currentScreen = .results
                case .idle:
                    self?.currentScreen = .lobby
                }
            }
            .store(in: &cancellables)
    }
}
