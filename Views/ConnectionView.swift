import SwiftUI
import MultipeerConnectivity

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var shakeMode = false

    private var canStart: Bool {
        appState.session.isHost && !appState.session.connectedPeers.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                roleIndicator

                Divider()

                PeerListView(session: appState.session)

                Spacer()

                // Start Game — visible as soon as host has 1+ peer
                if canStart {
                    VStack(spacing: 12) {
                        Toggle(isOn: $shakeMode) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                Text("Shake Mode")
                                    .font(.subheadline)
                            }
                        }
                        .tint(.orange)
                        .padding(.horizontal)

                        ActionButton(title: "Start Game", style: .primary) {
                            appState.gameEngine.startGame(shakeMode: shakeMode)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    connectionButtons
                }
            }
            .padding()
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        appState.goToHome()
                    }
                }
            }
            .animation(.easeInOut, value: canStart)
            .animation(.easeInOut, value: appState.session.role)
        }
    }

    @ViewBuilder
    private var roleIndicator: some View {
        if let role = appState.session.role {
            HStack {
                Image(systemName: role == .host ? "crown.fill" : "person.fill")
                    .foregroundStyle(role == .host ? .orange : .blue)
                Text(role == .host ? "You are the HOST" : "You are a GUEST")
                    .font(.subheadline.bold())
                    .foregroundStyle(role == .host ? .orange : .blue)

                if appState.session.connectedPeers.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                    Text(role == .host ? "Waiting for players..." : "Searching for host...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill((role == .host ? Color.orange : Color.blue).opacity(0.1))
            )
        }
    }

    @ViewBuilder
    private var connectionButtons: some View {
        if appState.session.role == nil {
            HStack(spacing: 16) {
                ActionButton(title: "Host Game", style: .primary) {
                    appState.session.startHosting()
                }
                ActionButton(title: "Join Game", style: .secondary) {
                    appState.session.startBrowsing()
                }
            }
        } else if appState.session.connectedPeers.isEmpty {
            ActionButton(title: "Cancel", style: .secondary) {
                appState.session.disconnect()
            }
        }
    }
}
