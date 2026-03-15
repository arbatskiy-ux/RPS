import SwiftUI

struct TimerView: View {
    @ObservedObject var timer: RoundTimer

    private var isUrgent: Bool { timer.timeRemaining <= 10 }

    var body: some View {
        Text(timer.formattedTime)
            .font(.title2.monospacedDigit().bold())
            .foregroundStyle(isUrgent ? .red : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut, value: isUrgent)
    }
}
