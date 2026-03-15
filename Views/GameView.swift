import SwiftUI

struct GameView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch appState.gameEngine.phase {
            case .countdown(let value):
                CountdownOverlay(value: value)

            case .movePause:
                VStack(spacing: 12) {
                    Text("Round \(appState.gameEngine.state.round) of \(appState.gameEngine.state.totalRounds)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Get ready...")
                        .foregroundStyle(.white.opacity(0.7))
                }

            default:
                gameContent
            }
        }
        .onAppear {
            appState.motionManager.startShakeDetection { [weak appState] in
                appState?.gameEngine.handleShake()
            }
        }
        .onDisappear {
            appState.motionManager.stopShakeDetection()
        }
    }

    private var gameContent: some View {
        VStack(spacing: 0) {
            // Top bar: scoreboard + timer + leave
            HStack(alignment: .top) {
                ScoreboardView(engine: appState.gameEngine)
                Spacer()
                VStack(spacing: 4) {
                    TimerView(timer: appState.gameEngine.roundTimer)
                    Text("Round \(appState.gameEngine.state.round)/\(appState.gameEngine.state.totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Leave") {
                        appState.gameEngine.endGame()
                        appState.session.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .padding()

            Spacer()

            // Current move instruction
            if let move = appState.gameEngine.state.currentMove {
                MoveInstructionView(move: move)
            }

            Spacer()

            // Action area — context-sensitive controls
            if let move = appState.gameEngine.state.currentMove {
                moveControls(for: move)
                    .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func moveControls(for move: Move) -> some View {
        switch move.kind {
        case .tapFast:
            Button {
                appState.gameEngine.handlePlayerAction(.tap)
            } label: {
                Text("TAP!")
                    .font(.title.bold())
                    .frame(width: 160, height: 160)
                    .background(Color.green.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }

        case .shakeIt:
            VStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                Text("Shake your device!")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.headline)
            }

        case .holdSteady:
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.cyan)
                Text("Don't move!")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.headline)
            }
        }
    }
}

// MARK: - Subviews

struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .transition(.scale.combined(with: .opacity))
            .animation(.easeOut(duration: 0.3), value: value)
    }
}

struct MoveInstructionView: View {
    let move: Move

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: moveIcon)
                .font(.system(size: 40))
                .foregroundStyle(moveColor)

            Text(move.instruction)
                .font(.title.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 32)
    }

    private var moveIcon: String {
        switch move.kind {
        case .tapFast: return "hand.tap.fill"
        case .shakeIt: return "iphone.radiowaves.left.and.right"
        case .holdSteady: return "hand.raised.fill"
        }
    }

    private var moveColor: Color {
        switch move.kind {
        case .tapFast: return .green
        case .shakeIt: return .yellow
        case .holdSteady: return .cyan
        }
    }
}
