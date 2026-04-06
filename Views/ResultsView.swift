import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var appState: AppState

    private var state: GameState { appState.gameEngine.state }
    private var isHost: Bool { appState.gameEngine.isHost }
    private var localName: String { isHost ? state.hostName : state.guestName }

    private var didWin: Bool { state.matchWinner == localName }

    private var winnerName: String { state.matchWinner ?? localName }
    private var loserName: String {
        winnerName == state.hostName ? state.guestName : state.hostName
    }

    private var winnerAvatarData: Data? {
        winnerName == state.hostName
            ? (isHost ? appState.avatarData : appState.opponentAvatarData)
            : (isHost ? appState.opponentAvatarData : appState.avatarData)
    }

    private var loserAvatarData: Data? {
        loserName == state.hostName
            ? (isHost ? appState.avatarData : appState.opponentAvatarData)
            : (isHost ? appState.opponentAvatarData : appState.avatarData)
    }

    private var scoreLabel: String {
        "\(max(state.hostWins, state.guestWins)) /\(min(state.hostWins, state.guestWins))"
    }

    private var accentColor: Color {
        didWin ? Color(red: 0.310, green: 0.937, blue: 0.404)  // #4fef67 green
               : Color(red: 0.988, green: 0.078, blue: 0.094)  // #fc1418 red
    }

    var body: some View {
        ZStack {
            Color(red: 0.047, green: 0.047, blue: 0.047).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    cardsSection
                    bottomSection
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.047, green: 0.137, blue: 0.392),
                    Color(red: 0.047, green: 0.047, blue: 0.047)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    appState.gameEngine.endGame()
                    appState.goToHome()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .padding(.top, 60)
                .padding(.leading, 16)

                Text(didWin ? "You Won the\nMatch!" : "You Lost the\nMatch!")
                    .font(.system(size: 47, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Cards

    private var cardsSection: some View {
        // Loser card rendered first (behind), winner card on top
        ZStack {
            PlayerResultCard(
                name: loserName,
                avatarData: loserAvatarData,
                isWinner: false,
                badgeText: nil,
                scoreText: nil
            )
            .rotationEffect(.degrees(5), anchor: .center)

            PlayerResultCard(
                name: winnerName,
                avatarData: winnerAvatarData,
                isWinner: true,
                badgeText: "Winner",
                scoreText: scoreLabel
            )
            .rotationEffect(.degrees(-4), anchor: .center)
            .offset(x: -30, y: -20)
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
        // shift loser card right so it peeks from behind
        .offset(x: 24)
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Round History")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.top, 24)
                .padding(.bottom, 8)

            ForEach(Array(state.roundResults.enumerated()), id: \.offset) { _, result in
                RoundHistoryRow(
                    roundNumber: result.round,
                    localChoice: isHost ? result.hostChoice : result.guestChoice,
                    opponentChoice: isHost ? result.guestChoice : result.hostChoice,
                    outcome: outcomeLabel(result)
                )
            }

            buttonsSection
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 56)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.047, green: 0.047, blue: 0.047), accentColor],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 28, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 28
        ))
    }

    private func outcomeLabel(_ result: RoundResult) -> String {
        guard let winner = result.winnerName else { return "Draw" }
        return winner == localName ? "Win" : "Loss"
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            if appState.session.isConnected {
                if appState.gameEngine.isHost {
                    Button {
                        appState.gameEngine.startGame(shakeMode: state.isShakeModeEnabled)
                    } label: {
                        Text("Play Again")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.047, green: 0.047, blue: 0.047))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(accentColor, in: Capsule())
                    }
                } else {
                    Text("Waiting for host...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }

            Button {
                appState.gameEngine.endGame()
                appState.goToHome()
            } label: {
                Text("Back to Home")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.1), in: Capsule())
            }
        }
    }
}

// MARK: - Player Result Card

private struct PlayerResultCard: View {
    let name: String
    let avatarData: Data?
    let isWinner: Bool
    let badgeText: String?
    let scoreText: String?

    private var cardGradient: LinearGradient {
        isWinner
            ? LinearGradient(
                colors: [Color(red: 0.302, green: 0.937, blue: 0.4), Color(red: 0.992, green: 0.894, blue: 0.749)],
                startPoint: .top, endPoint: .bottom
              )
            : LinearGradient(
                colors: [Color(red: 0.361, green: 0.376, blue: 0.867), Color(red: 0.851, green: 0.835, blue: 0.961)],
                startPoint: .bottomLeading, endPoint: .topTrailing
              )
    }

    var body: some View {
        VStack(spacing: 24) {
            PlayerAvatar(name: name, imageData: avatarData, size: 140)

            HStack(spacing: 12) {
                if let badge = badgeText {
                    pillLabel(badge)
                }
                if let score = scoreText {
                    pillLabel(score)
                }
                if badgeText == nil {
                    pillLabel(name)
                }
            }
        }
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 36)
        .frame(width: 275)
        .background(cardGradient, in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.55), radius: 50, x: 11, y: 4)
    }

    private func pillLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(red: 0.047, green: 0.047, blue: 0.047))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.white, in: Capsule())
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
        default:     return .white.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(roundNumber)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .leading)

            Spacer()

            HStack(spacing: 16) {
                RPSIcon(choice: localChoice, size: 24)
                Text("VS")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                RPSIcon(choice: opponentChoice, size: 24)
            }

            Spacer()

            Text(outcome)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(outcomeColor)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)
        }
    }
}

// MARK: - RPS choice icon using SF Symbols (emoji rendering unreliable on iOS 26)

private struct RPSIcon: View {
    let choice: RPSChoice
    let size: CGFloat

    private var systemName: String {
        switch choice {
        case .rock:     return "circle.fill"
        case .paper:    return "hand.raised.fill"
        case .scissors: return "scissors"
        }
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size + 8, height: size + 8)
    }
}
