import SwiftUI

/// Game Screen — displays countdown, symbols, shake mode, and choosing phase.
struct GameView: View {
    @EnvironmentObject private var appState: AppState

    private var engine: GameEngine { appState.gameEngine }

    private var isChoosing: Bool {
        if case .choosing = engine.phase { return true }
        return false
    }

    // Keeps overlay alive through the full emoji animation even after engine moves on
    @State private var showChooseOverlay = false
    @State private var cachedTimeRemaining = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerContent
                Spacer()
            }

            // Full-screen Choose Move overlay
            if showChooseOverlay {
                ChooseMoveView(
                    timeRemaining: isChoosing ? engine.choiceTimeRemaining : cachedTimeRemaining
                ) { choice in
                    engine.choose(choice)
                } onAnimationComplete: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showChooseOverlay = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showChooseOverlay)
        .onChange(of: isChoosing) { nowChoosing in
            if nowChoosing {
                cachedTimeRemaining = engine.choiceTimeRemaining
                showChooseOverlay = true
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
            VStack(spacing: 16) {
                Text("Round \(engine.state.currentRound)")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))

                Text(engine.countdownLabel)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: engine.countdownLabel)
                    .id(engine.countdownLabel)

                Text("\(engine.countdownValue)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: engine.countdownValue)
            }

        case .choosing:
            EmptyView() // Handled by ChooseMoveView overlay

        case .reveal(let result):
            RevealView(result: result, state: engine.state, isHost: engine.isHost)

        case .matchResult, .idle:
            EmptyView()
        }
    }
}

// MARK: - Choose Move View

struct ChooseMoveView: View {
    let timeRemaining: Int
    let onChoice: (RPSChoice) -> Void
    let onAnimationComplete: () -> Void

    @State private var tappedChoice: RPSChoice? = nil
    @State private var emojiPopped = false
    @State private var emojiExpanded = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base dark background
                LinearGradient(
                    stops: [
                        .init(color: Color(r: 36, g: 74, b: 100), location: 0.0),
                        .init(color: Color(r: 12, g: 12, b: 12), location: 0.475)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()

                // Colored glow from bottom when expanded
                if emojiExpanded, let choice = tappedChoice {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [choice.expandedGlowColor, .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: geo.size.height * 0.58)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }

                // "Choose your move!" title + circular timer
                VStack(spacing: 32) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 52)
                    Text("Choose\nyour\nmove!")
                        .font(.system(size: 70, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)
                        .opacity(tappedChoice == nil ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: tappedChoice == nil)

                    // Circular countdown timer
                    if tappedChoice == nil {
                        let isUrgent = timeRemaining <= 2
                        let timerColor: Color = isUrgent ? .red : .white
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: CGFloat(timeRemaining) / 5.0)
                                .stroke(
                                    timerColor.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: timeRemaining)
                            Text("\(timeRemaining)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(timerColor)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: timeRemaining)
                        }
                        .frame(width: 72, height: 72)
                        .scaleEffect(isUrgent ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isUrgent)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()
                }

                // Full-screen emoji (expands to center after pop)
                if emojiExpanded, let choice = tappedChoice {
                    Text(choice.symbol)
                        .font(.system(size: 270))
                        .rotationEffect(choice == .paper ? .degrees(-15) : .zero)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale(scale: 0.25).combined(with: .opacity))
                }

                // Buttons (hidden after expand)
                if !emojiExpanded {
                    VStack(spacing: 32) {
                        ForEach(RPSChoice.allCases, id: \.self) { choice in
                            choiceButtonRow(choice)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: emojiExpanded)
        }
    }

    @ViewBuilder
    private func choiceButtonRow(_ choice: RPSChoice) -> some View {
        let isSelected = tappedChoice == choice

        ZStack {
            // Button shell (clipped to capsule)
            HStack {
                Spacer()
                Text(choice.label)
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(isSelected ? 0 : 1)
                Spacer()
                // Space placeholder where emoji normally sits
                Color.clear.frame(width: 64, height: 50)
            }
            .padding(.horizontal, 30)
            .frame(height: 80)
            .background(choice.buttonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .overlay(RoundedRectangle(cornerRadius: 40).stroke(choice.borderColor, lineWidth: 2))

            // Emoji (NOT inside clipped capsule — floats freely)
            HStack {
                Spacer()
                Text(choice.symbol)
                    .font(.system(size: isSelected && emojiPopped ? 88 : 50))
                    .offset(y: isSelected && emojiPopped ? -64 : 0)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.45),
                        value: emojiPopped
                    )
                    .padding(.trailing, 26)
            }
            .frame(height: 80)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap(choice)
        }
        .disabled(tappedChoice != nil)
    }

    private func handleTap(_ choice: RPSChoice) {
        guard tappedChoice == nil else { return }
        onChoice(choice)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            tappedChoice = choice
            emojiPopped = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                emojiExpanded = true
            }
            // Hold fullscreen emoji ~4s then hand off to result screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onAnimationComplete()
            }
        }
    }
}

// MARK: - RPSChoice design extensions

private extension RPSChoice {
    var buttonGradient: LinearGradient {
        switch self {
        case .rock:
            return LinearGradient(
                colors: [Color(hex: "4eee67"), Color(hex: "2e8557")],
                startPoint: .top, endPoint: .bottom
            )
        case .paper:
            return LinearGradient(
                colors: [Color(hex: "a533ff"), Color(hex: "46007e")],
                startPoint: .top, endPoint: .bottom
            )
        case .scissors:
            return LinearGradient(
                colors: [Color(hex: "d84921"), Color(hex: "731900")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    var borderColor: Color {
        switch self {
        case .rock:     return Color(hex: "206841")
        case .paper:    return Color(hex: "50008f")
        case .scissors: return Color(hex: "4a1000")
        }
    }

    var expandedGlowColor: Color {
        switch self {
        case .rock:     return Color(hex: "2e8557")
        case .paper:    return Color(hex: "762aad")
        case .scissors: return Color(hex: "731900")
        }
    }
}

// MARK: - Color helpers

private extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }

    init(r: Int, g: Int, b: Int) {
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
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

struct RevealView: View {
    let result: RoundResult
    let state: GameState
    let isHost: Bool

    private var localChoice: RPSChoice {
        isHost ? result.hostChoice : result.guestChoice
    }

    private var opponentChoice: RPSChoice {
        isHost ? result.guestChoice : result.hostChoice
    }

    private var localName: String {
        isHost ? state.hostName : state.guestName
    }

    private var resultText: String {
        if let winner = result.winnerName {
            return winner == localName ? "You Win!" : "You Lose!"
        }
        return "Draw!"
    }

    private var resultColor: Color {
        if let winner = result.winnerName {
            return winner == localName ? .green : .red
        }
        return .yellow
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Round \(result.round)")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text(localChoice.symbol)
                        .font(.system(size: 72))
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text("vs")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.3))

                VStack(spacing: 8) {
                    Text(opponentChoice.symbol)
                        .font(.system(size: 72))
                    Text("Them")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Text(resultText)
                .font(.largeTitle.bold())
                .foregroundStyle(resultColor)

            if result.winnerName == nil {
                Text("Replaying round...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
