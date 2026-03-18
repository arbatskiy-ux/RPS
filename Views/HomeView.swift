import SwiftUI

/// Home Screen — main menu with "Find Player" button.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Logo area
                VStack(spacing: 16) {
                    // Placeholder: replace with app_icon asset
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("RPS")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("Rock • Paper • Scissors")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Player name
                PlayerNameField(name: $appState.playerName)

                // Find Player button
                ActionButton(title: "Find Player", style: .primary) {
                    appState.goToConnection()
                }

                // Solo mode — play against CPU
                ActionButton(title: "Solo Practice", style: .secondary) {
                    appState.startSoloGame()
                }

                Spacer()
            }
            .padding()
        }
    }
}
