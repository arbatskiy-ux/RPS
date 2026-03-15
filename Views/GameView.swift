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
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 16) {
                PlayerScorePill(name: engine.state.hostName, wins: engine.state.hostWins, isLocal: engine.isHost)
                Text("vs")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))
                PlayerScorePill(name: engine.state.guestName, wins: engine.state.guestWins, isLocal: !engine.isHost)
            }
            Spacer()
            Button("Leave") {
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

                // "Rock..." / "Paper..." / "Scissors!"
                Text(engine.countdownLabel)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: engine.countdownLabel)
                    .id(engine.countdownLabel) // force re-render for animation

                Text("\(engine.countdownValue)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: engine.countdownValue)
            }

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

        case .reveal(let result):
            RevealView(result: result, state: engine.state, isHost: engine.isHost)

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

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, isActive: true)

            Text("Shake to Start!")
                .font(.title.bold())
                .foregroundStyle(.white)

            // Shake counter: 3 dots
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < motionManager.shakeCount ? Color.orange : Color.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.2), value: motionManager.shakeCount)
                }
            }

            Text("\(motionManager.shakeCount) / 3")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
        .onAppear {
            motionManager.startCountedShakes(
                target: 3,
                onShake: {
                    engine.hapticManager.playShakePulse()
                },
                onComplete: {
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

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.bold())
                .foregroundStyle(isLocal ? .yellow : .white)
                .lineLimit(1)
            Text("\(wins)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

            // Both moves displayed — same result on both devices
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    // Placeholder: use Image(localChoice.imageName) when assets are added
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
