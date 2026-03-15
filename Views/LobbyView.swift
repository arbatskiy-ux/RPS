import SwiftUI
import MultipeerConnectivity

struct LobbyView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHosting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("PeerPlay")
                    .font(.largeTitle.bold())

                PlayerNameField(name: $appState.playerName)

                Divider()

                PeerListView(session: appState.session)

                Spacer()

                HStack(spacing: 16) {
                    ActionButton(title: "Host Game", style: .primary) {
                        appState.session.startHosting()
                        isHosting = true
                    }

                    ActionButton(title: "Browse", style: .secondary) {
                        appState.session.startBrowsing()
                    }
                }
            }
            .padding()
            .navigationTitle("Lobby")
        }
    }
}
