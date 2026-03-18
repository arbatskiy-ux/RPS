import SwiftUI

// MARK: - Shared preview helper

private let previewAppState = AppState()

// MARK: - Home Screen

#Preview("Home") {
    HomeView()
        .environmentObject(previewAppState)
}

// MARK: - Connection Screen

#Preview("Connection — idle") {
    ConnectionView()
        .environmentObject(previewAppState)
}

// MARK: - Game Screen — Countdown

#Preview("Game — Countdown") {
    GamePreviewWrapper(phase: .countdown(3), countdownLabel: "Rock...")
}

// MARK: - Game Screen — Choosing

#Preview("Game — Choosing") {
    GamePreviewWrapper(phase: .choosing)
}

// MARK: - Game Screen — Reveal (Win)

#Preview("Game — Reveal Win") {
    GamePreviewWrapper(phase: .reveal(RoundResult(
        round: 1,
        hostChoice: .rock,
        guestChoice: .scissors,
        winnerName: "You"
    )))
}

// MARK: - Game Screen — Reveal (Lose)

#Preview("Game — Reveal Lose") {
    GamePreviewWrapper(phase: .reveal(RoundResult(
        round: 1,
        hostChoice: .scissors,
        guestChoice: .rock,
        winnerName: "CPU"
    )))
}

// MARK: - Game Screen — Reveal (Draw)

#Preview("Game — Draw") {
    GamePreviewWrapper(phase: .reveal(RoundResult(
        round: 1,
        hostChoice: .rock,
        guestChoice: .rock,
        winnerName: nil
    )))
}

// MARK: - Result Screen

#Preview("Results — Win") {
    ResultsPreviewWrapper(playerWon: true)
}

#Preview("Results — Lose") {
    ResultsPreviewWrapper(playerWon: false)
}

// MARK: - Helpers

private struct GamePreviewWrapper: View {
    let phase: GamePhase
    var countdownLabel: String = ""

    var body: some View {
        let state = AppState()
        return ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Mini top bar
                HStack {
                    Text("You  0 — 0  CPU")
                        .foregroundStyle(.white)
                        .font(.caption)
                    Spacer()
                }
                .padding()

                Spacer()

                // Phase content
                switch phase {
                case .countdown(let v):
                    VStack(spacing: 16) {
                        Text("Round 1")
                            .font(.title3).foregroundStyle(.white.opacity(0.6))
                        Text(countdownLabel)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(v)")
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                case .choosing:
                    VStack(spacing: 20) {
                        Text("Choose your move!")
                            .font(.title.bold()).foregroundStyle(.white)
                        Text("5")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                case .reveal(let result):
                    RevealView(
                        result: result,
                        state: {
                            var s = GameState()
                            s.hostName = "You"
                            s.guestName = "CPU"
                            return s
                        }(),
                        isHost: true
                    )
                default:
                    EmptyView()
                }

                Spacer()

                if case .choosing = phase {
                    RPSChoiceButtons { _ in }
                        .padding(.bottom, 40)
                }
            }
        }
        .environmentObject(state)
    }
}

private struct ResultsPreviewWrapper: View {
    let playerWon: Bool

    var body: some View {
        let state = AppState()
        state.gameEngine.previewState = {
            var s = GameState()
            s.hostName = "You"
            s.guestName = "CPU"
            s.hostWins = playerWon ? 2 : 0
            s.guestWins = playerWon ? 0 : 2
            s.roundResults = [
                RoundResult(round: 1, hostChoice: .rock, guestChoice: .scissors, winnerName: playerWon ? "You" : "CPU"),
                RoundResult(round: 2, hostChoice: .paper, guestChoice: .rock, winnerName: playerWon ? "You" : "CPU")
            ]
            return s
        }()
        return ResultsView()
            .environmentObject(state)
    }
}
