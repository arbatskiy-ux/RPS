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
                    Button("Leave") {
                        appState.gameEngine.endGame()
                        appState.session.disconnect()
                    }
                    .buttonStyle(.bordered)
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
