import SwiftUI

struct GameControlsView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        HStack(spacing: 32) {
            // TODO: Replace with game-specific controls
            Button {
                engine.handlePlayerAction(.tap)
            } label: {
                Image(systemName: "hand.tap")
                    .font(.largeTitle)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }
}
