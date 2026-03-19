import SwiftUI
import Combine

/// Global application state shared across the entire app.
final class AppState: ObservableObject {
    enum Screen {
        case home
        case connection
        case game
        case results
    }

    @Published var currentScreen: Screen = .home

    /// Player's custom display name — persisted across app launches.
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: "playerName") }
    }

    /// Total rounds per match (3–10). roundsToWin = roundCount / 2 + 1.
    @Published var roundCount: Int {
        didSet { UserDefaults.standard.set(roundCount, forKey: "roundCount") }
    }

    /// Player avatar image data — persisted across app launches.
    @Published var avatarData: Data? {
        didSet { UserDefaults.standard.set(avatarData, forKey: "avatarData") }
    }

    let session: MultipeerSession
    let gameEngine: GameEngine
    let hapticManager: HapticManager
    let motionManager: MotionManager
    let audioManager: AudioManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        let savedName   = UserDefaults.standard.string(forKey: "playerName") ?? ""
        let savedRounds = UserDefaults.standard.integer(forKey: "roundCount")
        let savedAvatar = UserDefaults.standard.data(forKey: "avatarData")

        self.playerName = savedName
        self.roundCount = savedRounds > 0 ? savedRounds : 3
        self.avatarData = savedAvatar

        let session        = MultipeerSession(displayName: UIDevice.current.name)
        let hapticManager  = HapticManager()
        let motionManager  = MotionManager()
        let audioManager   = AudioManager()
        let gameEngine     = GameEngine(session: session,
                                        hapticManager: hapticManager,
                                        audioManager: audioManager)

        self.session        = session
        self.gameEngine     = gameEngine
        self.hapticManager  = hapticManager
        self.motionManager  = motionManager
        self.audioManager   = audioManager

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
        let name = playerName.isEmpty ? UIDevice.current.name : playerName
        session.startAutoConnect(playerName: name)
    }

    func goToHome() {
        session.disconnect()
        gameEngine.endGame()
        currentScreen = .home
        // playerName intentionally NOT reset — persists for next session
    }

    /// Start a solo game against CPU (no network needed).
    func startSoloGame() {
        let name = playerName.isEmpty ? "Игрок" : playerName
        gameEngine.startSoloGame(playerName: name, roundCount: roundCount)
    }
}
