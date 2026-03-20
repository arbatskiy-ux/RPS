import SwiftUI
import MultipeerConnectivity

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var shakeMode = false

    private var hasOpponent: Bool {
        !appState.session.connectedPeers.isEmpty
    }

    /// Only the HOST can start the game.
    private var canStartGame: Bool {
        appState.session.isHost && hasOpponent
    }

    /// The opponent's custom player name (or device name as fallback).
    private var opponentName: String? {
        guard let peer = appState.session.connectedPeers.first else { return nil }
        return appState.session.peerDisplayNames[peer] ?? peer.displayName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Search / Opponent area ──────────────────────────────────
                VStack(spacing: 20) {
                    Spacer().frame(height: 32)

                    if hasOpponent {
                        opponentCard
                    } else {
                        searchingView
                    }

                    if !hasOpponent {
                        Label(
                            "Попросите соперника включить Wi-Fi для участия в игре",
                            systemImage: "wifi"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    }

                    Spacer()
                }

                // ── Settings & actions ─────────────────────────────────────
                VStack(spacing: 16) {
                    Divider()

                    // Режим тряски
                    Toggle(isOn: $shakeMode) {
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(.orange)
                            Text("Режим тряски")
                                .font(.subheadline)
                        }
                    }
                    .tint(.orange)
                    .padding(.horizontal)

                    // Слайдер раундов
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Раундов")
                                .font(.subheadline)
                            Spacer()
                            Text("\(appState.roundCount)")
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)

                        Slider(
                            value: Binding(
                                get: { Double(appState.roundCount) },
                                set: { appState.roundCount = Int($0) }
                            ),
                            in: 3...10,
                            step: 1
                        )
                        .tint(.blue)
                        .padding(.horizontal)
                        .onChange(of: appState.roundCount) { _ in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }

                        HStack {
                            Text("3")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("10")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Кнопка действия
                    Group {
                        if hasOpponent {
                            if canStartGame {
                                ActionButton(title: "Начать турнир", style: .primary) {
                                    appState.gameEngine.startGame(
                                        shakeMode: shakeMode,
                                        roundCount: appState.roundCount
                                    )
                                }
                            } else {
                                // GUEST ждёт, пока хост запустит игру
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Ожидание хоста...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            ActionButton(title: "Играть одному", style: .secondary) {
                                appState.startSoloGame()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Соперники")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Назад") {
                        appState.goToHome()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasOpponent)
            .animation(.easeInOut(duration: 0.3), value: canStartGame)
            .onAppear {
                // Restart searching if not already connected or searching
                if !appState.session.isConnected && appState.session.role == nil {
                    let name = appState.playerName.isEmpty
                        ? UIDevice.current.name
                        : appState.playerName
                    appState.session.startAutoConnect(playerName: name)
                }
            }
        }
    }

    // MARK: - Subviews

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
                .scaleEffect(1.4)

            Text("Поиск соперников...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var opponentCard: some View {
        VStack(spacing: 10) {
            PlayerAvatar(
                name: opponentName ?? "Соперник",
                imageData: appState.opponentAvatarData,
                size: 72
            )

            Text(opponentName ?? "Соперник")
                .font(.title2.bold())

            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Подключён")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
