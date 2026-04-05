import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.currentScreen {
        case .onboarding:
            OnboardingView(onComplete: { appState.goToHome() })
        case .home:
            HomeView()
        case .connection:
            ConnectionView()
        case .game:
            GameView()
        case .results:
            ResultsView()
        }
    }
}
