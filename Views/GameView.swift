import SwiftUI

struct GameView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            GameSceneView(engine: appState.gameEngine)

            VStack {
                HStack {
                    ScoreboardView(engine: appState.gameEngine)
                    Spacer()
                    VStack(spacing: 4) {
                        TimerView(timer: appState.gameEngine.roundTimer)
                        Button("Leave") {
                            appState.gameEngine.endGame()
                            appState.session.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()

                Spacer()

                GameControlsView(engine: appState.gameEngine)
                    .padding()
            }
        }
        .onAppear {
            appState.motionManager.startShakeDetection { [weak appState] in
                appState?.gameEngine.handleShake()
            }
        }
        .onDisappear {
            appState.motionManager.stopShakeDetection()
        }
    }
}
