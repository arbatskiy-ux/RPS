import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.currentScreen {
        case .lobby:
            LobbyView()
        case .game:
            GameView()
        case .results:
            ResultsView()
        }
    }
}
