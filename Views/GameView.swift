import SwiftUI

/// Game Screen — displays countdown, symbols, shake mode, and choosing phase.
struct GameView: View {
    @EnvironmentObject private var appState: AppState
    private var engine: GameEngine { appState.gameEngine }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerContent
                Spacer()
                bottomArea
            }

            // Full-screen countdown overlay
            if case .countdown = engine.phase {
                CountdownOverlayView(
                    countdownValue: engine.countdownValue,
                    countdownLabel: engine.countdownLabel,
                    currentRound: engine.state.currentRound,
                    hostName: engine.state.hostName,
                    guestName: engine.state.guestName,
                    hostAvatarData: hostAvatarData,
                    guestAvatarData: guestAvatarData
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // Full-screen round result overlay
            if case .reveal(let result) = engine.phase {
                RevealView(result: result, state: engine.state, isHost: engine.isHost)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

        }
    }

    // MARK: - Top Bar

    private var hostAvatarData: Data? {
        engine.isHost ? appState.avatarData : appState.opponentAvatarData
    }

    private var guestAvatarData: Data? {
        engine.isHost ? appState.opponentAvatarData : appState.avatarData
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                PlayerScorePill(
                    name: engine.state.hostName,
                    wins: engine.state.hostWins,
                    isLocal: engine.isHost,
                    avatarData: hostAvatarData
                )
                Text("vs")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))
                PlayerScorePill(
                    name: engine.state.guestName,
                    wins: engine.state.guestWins,
                    isLocal: !engine.isHost,
                    avatarData: guestAvatarData
                )
            }
            Spacer()
            Button("Выйти") {
                engine.endGame()
                appState.session.disconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
        }
        .padding()
    }

    // MARK: - Center Content (phase-dependent)

    @ViewBuilder
    private var centerContent: some View {
        switch engine.phase {
        case .shakeReady:
            ShakeModeView(motionManager: appState.motionManager, engine: engine)

        case .countdown:
            EmptyView() // handled by CountdownOverlayView

        case .choosing:
            VStack(spacing: 20) {
                Text("Round \(engine.state.currentRound)")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))

                if engine.localChoice != nil {
                    VStack(spacing: 12) {
                        Text(engine.localChoice!.symbol)
                            .font(.system(size: 80))
                        Text("Waiting for opponent...")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.headline)
                    }
                } else {
                    Text("Choose your move!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

                Text("\(engine.choiceTimeRemaining)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(engine.choiceTimeRemaining <= 2 ? .red : .white.opacity(0.8))
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: engine.choiceTimeRemaining)
            }

        case .reveal:
            EmptyView() // handled by full-screen RevealView overlay

        case .matchResult, .idle:
            EmptyView()
        }
    }

    // MARK: - Bottom Area

    @ViewBuilder
    private var bottomArea: some View {
        if case .choosing = engine.phase, engine.localChoice == nil {
            RPSChoiceButtons { choice in
                engine.choose(choice)
            }
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Shake Mode View

struct ShakeModeView: View {
    @ObservedObject var motionManager: MotionManager
    @ObservedObject var engine: GameEngine
    @State private var isPulsing = false
    @State private var phoneOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .offset(x: phoneOffset)
                .animation(
                    .easeInOut(duration: 0.12).repeatForever(autoreverses: true),
                    value: phoneOffset
                )
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text("Встряхните телефон!")
                .font(.title.bold())
                .foregroundStyle(.white)
                .opacity(isPulsing ? 1.0 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Shake counter: 3 dots
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < motionManager.shakeCount ? Color.orange : Color.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .scaleEffect(index < motionManager.shakeCount ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: motionManager.shakeCount)
                }
            }

            Text("\(motionManager.shakeCount) / 3")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
        .onAppear {
            isPulsing = true
            phoneOffset = 6
            motionManager.startCountedShakes(
                target: 3,
                onShake: {
                    engine.hapticManager.playShakePulse(shakeNumber: motionManager.shakeCount)
                },
                onComplete: {
                    engine.hapticManager.playShakePulse(shakeNumber: 3)
                    engine.localPlayerShakeReady()
                }
            )
        }
        .onDisappear {
            motionManager.stopShakeDetection()
        }
    }
}

// MARK: - Countdown Overlay

struct CountdownOverlayView: View {
    let countdownValue: Int
    let countdownLabel: String
    let currentRound: Int
    let hostName: String
    let guestName: String
    let hostAvatarData: Data?
    let guestAvatarData: Data?

    private var themeColor: Color {
        switch countdownValue {
        case 3: return Color(red: 0.29, green: 0.878, blue: 0.4)      // Green (Rock)
        case 2: return Color(red: 0.455, green: 0.165, blue: 0.671)   // Purple (Paper)
        default: return Color(red: 0.643, green: 0.275, blue: 0.173)  // Red-Orange (Scissors)
        }
    }

    private var gradientAccent: Color {
        switch countdownValue {
        case 3: return Color(red: 0.31, green: 0.937, blue: 0.404)
        case 2: return Color(red: 0.463, green: 0.165, blue: 0.678)
        default: return Color(red: 0.678, green: 0.286, blue: 0.165)
        }
    }

    private var cleanLabel: String {
        countdownLabel
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "!", with: "")
    }

    var body: some View {
        ZStack {
            // Dark angled background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.047, green: 0.047, blue: 0.047), location: 0.525),
                    .init(color: Color(red: 0.141, green: 0.29, blue: 0.392), location: 0.99)
                ],
                startPoint: UnitPoint(x: 0.6, y: 1.0),
                endPoint: UnitPoint(x: 0.4, y: 0.0)
            )

            // Bottom colored glow
            VStack {
                Spacer()
                LinearGradient(
                    colors: [gradientAccent.opacity(0.8), gradientAccent.opacity(0)],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 380)
            }

            // Content
            VStack(spacing: 0) {
                Text("Round #\(currentRound)")
                    .font(.system(size: 50, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeColor)
                    .padding(.top, 70)

                // Avatar row
                HStack(spacing: 20) {
                    PlayerAvatar(name: hostName, imageData: hostAvatarData, size: 64)
                        .overlay(Circle().stroke(themeColor, lineWidth: 5))

                    Text("VS")
                        .font(.system(size: 50, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeColor)

                    PlayerAvatar(name: guestName, imageData: guestAvatarData, size: 64)
                        .overlay(Circle().stroke(themeColor, lineWidth: 5))
                }
                .padding(.top, 24)

                Spacer()

                // Giant countdown number
                Text("\(countdownValue)")
                    .font(.system(size: 300, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                // Label (Rock / Paper / Scissors)
                Text(cleanLabel)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
                    .transition(.scale.combined(with: .opacity))
                    .id(countdownLabel)

                Spacer()
                    .frame(height: 100)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: countdownValue)
    }
}

// MARK: - Subviews

struct PlayerScorePill: View {
    let name: String
    let wins: Int
    let isLocal: Bool
    var avatarData: Data? = nil

    var body: some View {
        HStack(spacing: 8) {
            PlayerAvatar(name: name, imageData: avatarData, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.bold())
                    .foregroundStyle(isLocal ? .yellow : .white)
                    .lineLimit(1)
                Text("\(wins)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RPSChoiceButtons: View {
    let onChoice: (RPSChoice) -> Void

    var body: some View {
        HStack(spacing: 24) {
            ForEach(RPSChoice.allCases, id: \.self) { choice in
                Button {
                    onChoice(choice)
                } label: {
                    VStack(spacing: 8) {
                        // Placeholder: use Image(choice.imageName) when assets are added
                        Text(choice.symbol)
                            .font(.system(size: 56))
                        Text(choice.label)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .frame(width: 100, height: 100)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

struct RevealView: View {
    let result: RoundResult
    let state: GameState
    let isHost: Bool

    private var localChoice: RPSChoice { isHost ? result.hostChoice : result.guestChoice }
    private var localName: String { isHost ? state.hostName : state.guestName }

    private var outcome: Outcome {
        guard let winner = result.winnerName else { return .draw }
        return winner == localName ? .win : .lose
    }

    enum Outcome { case win, lose, draw }

    private var characterImageName: String {
        switch (localChoice, outcome) {
        case (.rock,     .win):  return "rock_win"
        case (.rock,     .lose): return "rock_lose"
        case (.paper,    .win):  return "paper_win"
        case (.paper,    .lose): return "paper_lose"
        case (.scissors, .win):  return "scissors_win"
        case (.scissors, .lose): return "scissors_lose"
        default:                 return ""
        }
    }

    private var bgTop: Color    { Color(red: 0.047, green: 0.082, blue: 0.165) }
    private var bgBottom: Color {
        switch outcome {
        case .win:  return Color(red: 0.082, green: 0.612, blue: 0.082)
        case .lose: return Color(red: 0.784, green: 0.039, blue: 0.039)
        case .draw: return Color(red: 0.35, green: 0.35, blue: 0.06)
        }
    }
    private var buttonColor: Color {
        switch outcome {
        case .win:  return Color(red: 0.18, green: 0.72, blue: 0.18)
        case .lose: return Color(red: 0.55, green: 0.04, blue: 0.04)
        case .draw: return Color.gray
        }
    }
    private var resultLine1: String {
        switch outcome {
        case .win:  return "You"
        case .lose: return "You"
        case .draw: return "Draw!"
        }
    }
    private var resultLine2: String {
        switch outcome {
        case .win:  return "Win!"
        case .lose: return "Lose"
        case .draw: return ""
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Dark background
                bgTop.ignoresSafeArea()

                // Character — sized to ~69% height, 73% width, top-offset 16.5% (Figma 416:494)
                let imgName = characterImageName
                if !imgName.isEmpty {
                    Image(imgName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width:  geo.size.width  * 0.73,
                            height: geo.size.height * 0.69
                        )
                        .position(
                            x: geo.size.width  * 0.1372 + geo.size.width  * 0.73 / 2,
                            y: geo.size.height * 0.1654 + geo.size.height * 0.69 / 2
                        )
                } else {
                    Image(systemName: localChoice == .paper ? "hand.raised.fill" : "scissors")
                        .font(.system(size: 140))
                        .foregroundStyle(.white.opacity(0.6))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                }

                // Gradient overlay ON TOP of character — transparent → accent, overlaps legs
                LinearGradient(
                    stops: [
                        .init(color: .clear,   location: 0.0),
                        .init(color: .clear,   location: 0.42),
                        .init(color: bgBottom, location: 0.78),
                        .init(color: bgBottom, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // UI overlay: Round label + text + button
                VStack(spacing: 0) {
                    Text("Round \(result.round)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 60)

                    Spacer()

                    VStack(alignment: .center, spacing: -20) {
                        Text(resultLine1)
                            .font(.system(size: 80, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        if !resultLine2.isEmpty {
                            Text(resultLine2)
                                .font(.system(size: 80, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 30)

                    Text(result.winnerName == nil ? "Replaying..." : "Next round")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(buttonColor, in: Capsule())
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 50)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: result.round)
    }
}
