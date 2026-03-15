import SwiftUI

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
            // Score: HOST vs GUEST
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
        case .countdown(let value):
            VStack(spacing: 12) {
                Text("Round \(engine.state.currentRound)")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(value)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: value)
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

                // Choice timer
                Text("\(engine.choiceTimeRemaining)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(engine.choiceTimeRemaining <= 2 ? .red : .white.opacity(0.8))
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: engine.choiceTimeRemaining)
            }

        case .reveal(let result):
            RevealView(result: result, state: engine.state, isHost: engine.isHost)

        case .matchResult:
            // Handled by ResultsView via AppState screen routing
            EmptyView()

        case .idle:
            EmptyView()
        }
    }

    // MARK: - Bottom Area (choice buttons during choosing)

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

            // Symbols face-off
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

            // Result
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
