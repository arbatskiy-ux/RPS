import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(engine.state.scores.sorted(by: { $0.value > $1.value }), id: \.key) { name, score in
                HStack(spacing: 8) {
                    Text(name)
                        .font(.caption.bold())
                    Spacer()
                    Text("\(score)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 160)
    }
}
