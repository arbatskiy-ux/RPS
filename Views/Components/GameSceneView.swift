import SwiftUI

/// Main game canvas. Replace with SpriteKit/RealityKit/custom drawing as needed.
struct GameSceneView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // TODO: Render game-specific content here
                Text("Game Scene")
                    .foregroundStyle(.white)
                    .font(.title)
            }
        }
    }
}
