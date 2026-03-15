import Foundation
import Combine

/// Counts down a round and publishes ticks + completion.
final class RoundTimer: ObservableObject {
    @Published private(set) var timeRemaining: TimeInterval

    private let duration: TimeInterval
    private var timer: AnyCancellable?

    let onFinished = PassthroughSubject<Void, Never>()

    init(duration: TimeInterval = 60) {
        self.duration = duration
        self.timeRemaining = duration
    }

    func start() {
        timeRemaining = duration
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    stop()
                    onFinished.send()
                }
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    var formattedTime: String {
        let seconds = Int(timeRemaining)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
