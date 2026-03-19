import SwiftUI
import PhotosUI

/// Home Screen — main menu with name input, avatar, and mode selection.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
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

                // Avatar + name field
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        avatarView
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run { appState.avatarData = data }
                            }
                        }
                    }

                    PlayerNameField(name: $appState.playerName)
                }

                // Find Player
                ActionButton(title: "Найти игрока", style: .primary) {
                    appState.goToConnection()
                }

                // Solo Practice
                ActionButton(title: "Играть одному", style: .secondary) {
                    appState.startSoloGame()
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        Group {
            if let data = appState.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.separator), lineWidth: 1.5)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .background(Color(.systemBackground), in: Circle())
        }
    }
}
