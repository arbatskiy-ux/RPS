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

    /// Local player avatar — persisted across app launches.
    @Published var avatarData: Data? {
        didSet { UserDefaults.standard.set(avatarData, forKey: "avatarData") }
    }

    /// Opponent's avatar received over the network (not persisted).
    @Published var opponentAvatarData: Data?

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
        bindAvatarExchange()
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

    // MARK: - Avatar Exchange

    private func bindAvatarExchange() {
        // Send our avatar when a peer connects
        session.connectionEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .peerConnected = event {
                    self?.sendAvatarToPeer()
                }
                if case .peerDisconnected = event {
                    self?.opponentAvatarData = nil
                }
            }
            .store(in: &cancellables)

        // Receive opponent's avatar
        session.receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if case .avatarData(let data) = message.payload {
                    self?.opponentAvatarData = data
                }
            }
            .store(in: &cancellables)
    }

    private func sendAvatarToPeer() {
        guard let raw = avatarData,
              let compressed = compressAvatar(raw) else { return }
        let msg = GameMessage(
            senderName: playerName,
            payload: .avatarData(compressed)
        )
        session.send(message: msg)
    }

    /// Resize and compress avatar to small JPEG thumbnail for network transfer.
    private func compressAvatar(_ data: Data, side: CGFloat = 80) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        }
        return thumb.jpegData(compressionQuality: 0.75)
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
