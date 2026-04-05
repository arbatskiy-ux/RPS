import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var appState: AppState

    private var state: GameState { appState.gameEngine.state }
    private var isHost: Bool { appState.gameEngine.isHost }

    private var localName: String {
        isHost ? state.hostName : state.guestName
    }

    private var didWin: Bool {
        state.matchWinner == localName
    }

    private var hostAvatarData: Data? {
        isHost ? appState.avatarData : appState.opponentAvatarData
    }

    private var guestAvatarData: Data? {
        isHost ? appState.opponentAvatarData : appState.avatarData
    }

    // Winner gets green gradient, loser gets purple
    private var accentColor: Color {
        didWin ? Color(red: 0.31, green: 0.937, blue: 0.404)
               : Color(red: 0.463, green: 0.165, blue: 0.678)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark background
            Color(red: 0.047, green: 0.047, blue: 0.047)
                .ignoresSafeArea()

            // Bottom gradient glow (winner=green, loser=purple)
            LinearGradient(
                colors: [accentColor.opacity(0.55), accentColor.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 420)
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text(didWin ? "You Won the\nMatch!" : "You Lost the\nMatch!")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 28)

                    // Score card
                    scoreCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)

                    // Round History table
                    roundHistory

                    // Buttons
                    buttonsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 48)
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        HStack(spacing: 0) {
            // Host
            VStack(spacing: 8) {
                PlayerAvatar(name: state.hostName, imageData: hostAvatarData, size: 56)
                Text(state.hostName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            // Score
            VStack(spacing: 4) {
                Text("\(state.hostWins) – \(state.guestWins)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("score")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)

            // Guest
            VStack(spacing: 8) {
                PlayerAvatar(name: state.guestName, imageData: guestAvatarData, size: 56)
                Text(state.guestName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Round History

    private var roundHistory: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Round History")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 10)

            // Rows
            ForEach(Array(state.roundResults.enumerated()), id: \.offset) { _, result in
                RoundHistoryRow(
                    roundNumber: result.round,
                    localChoice: isHost ? result.hostChoice : result.guestChoice,
                    opponentChoice: isHost ? result.guestChoice : result.hostChoice,
                    outcome: outcomeLabel(result)
                )
            }
        }
    }

    private func outcomeLabel(_ result: RoundResult) -> String {
        guard let winner = result.winnerName else { return "Draw" }
        return winner == localName ? "Win" : "Loss"
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            if appState.session.isConnected && appState.gameEngine.isHost {
                // Green "Play Again" primary button
                Button {
                    appState.gameEngine.startGame(shakeMode: state.isShakeModeEnabled)
                } label: {
                    Text("Play Again")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.31, green: 0.937, blue: 0.404),
                                    Color(red: 0.18, green: 0.55, blue: 0.3)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                }
            } else if appState.session.isConnected {
                Text("Waiting for host...")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }

            // Back to Home
            Button {
                appState.gameEngine.endGame()
                appState.goToHome()
            } label: {
                Text("Back to Home")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
    }
}

// MARK: - Round History Row

private struct RoundHistoryRow: View {
    let roundNumber: Int
    let localChoice: RPSChoice
    let opponentChoice: RPSChoice
    let outcome: String

    private var outcomeColor: Color {
        switch outcome {
        case "Win":  return Color(red: 0.29, green: 0.878, blue: 0.4)
        case "Loss": return Color(red: 0.9, green: 0.35, blue: 0.3)
        default:     return Color.white.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Round number
            Text("\(roundNumber)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .leading)

            Spacer()

            // Choices
            HStack(spacing: 16) {
                Text(localChoice.symbol)
                    .font(.title2)
                Text("VS")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Text(opponentChoice.symbol)
                    .font(.title2)
            }

            Spacer()

            // Outcome
            Text(outcome)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(outcomeColor)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
    }
}
