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

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Trophy / result header
                VStack(spacing: 16) {
                    Text(didWin ? "🏆" : "😔")
                        .font(.system(size: 80))
                    Text(didWin ? "Вы победили!" : "Вы проиграли")
                        .font(.largeTitle.bold())

                    // Score row with avatars
                    HStack(spacing: 20) {
                        VStack(spacing: 6) {
                            PlayerAvatar(name: state.hostName, imageData: hostAvatarData, size: 52)
                            Text(state.hostName)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }

                        Text("\(state.hostWins) – \(state.guestWins)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        VStack(spacing: 6) {
                            PlayerAvatar(name: state.guestName, imageData: guestAvatarData, size: 52)
                            Text(state.guestName)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                    }
                }

                // Round-by-round breakdown
                VStack(spacing: 8) {
                    Text("Round History")
                        .font(.headline)

                    ForEach(Array(state.roundResults.enumerated()), id: \.offset) { index, result in
                        HStack {
                            Text("Round \(result.round)")
                                .font(.subheadline)
                                .frame(width: 70, alignment: .leading)

                            Spacer()

                            Text(result.hostChoice.symbol)
                                .font(.title2)
                            Text("vs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(result.guestChoice.symbol)
                                .font(.title2)

                            Spacer()

                            if let winner = result.winnerName {
                                Text(winner == localName ? "Win" : "Loss")
                                    .font(.caption.bold())
                                    .foregroundStyle(winner == localName ? .green : .red)
                                    .frame(width: 40)
                            } else {
                                Text("Draw")
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                                    .frame(width: 40)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Rematch / disconnect buttons
                if appState.session.isConnected {
                    VStack(spacing: 12) {
                        if appState.gameEngine.isHost {
                            ActionButton(title: "Play Again", style: .primary) {
                                appState.gameEngine.startGame(shakeMode: state.isShakeModeEnabled)
                            }
                        } else {
                            Text("Waiting for host to start...")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                        ActionButton(title: "Back to Home", style: .secondary) {
                            appState.gameEngine.endGame()
                            appState.goToHome()
                        }
                    }
                } else {
                    ActionButton(title: "Back to Home", style: .secondary) {
                        appState.goToHome()
                    }
                }
            }
            .padding()
        }
    }
}
