import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var appState: AppState

    private var sortedScores: [(name: String, score: Int)] {
        appState.gameEngine.state.scores
            .map { (name: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Round Over!")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                ForEach(Array(sortedScores.enumerated()), id: \.element.name) { index, entry in
                    HStack {
                        Text(medal(for: index))
                            .font(.title2)
                        Text(entry.name)
                            .font(.headline)
                        Spacer()
                        Text("\(entry.score) pts")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Text("Returning to lobby...")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding()
    }

    private func medal(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "  "
        }
    }
}
