import CoreMotion
import Combine

/// Detects shake gestures via CoreMotion accelerometer.
/// Supports both continuous shake detection and counted shake mode (N shakes to trigger).
final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published private(set) var shakeCount: Int = 0

    private var shakeHandler: (() -> Void)?
    private var lastShakeTime: Date = .distantPast
    private let shakeThreshold: Double = 2.5
    private let updateInterval: TimeInterval = 0.05
    private let shakeCooldown: TimeInterval = 0.4  // min time between counted shakes

    // MARK: - Continuous shake detection

    func startShakeDetection(handler: @escaping () -> Void) {
        guard motionManager.isAccelerometerAvailable else { return }
        shakeHandler = handler
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let magnitude = self.accelerationMagnitude(data.acceleration)
            if magnitude > self.shakeThreshold {
                self.shakeHandler?()
            }
        }
    }

    func stopShakeDetection() {
        motionManager.stopAccelerometerUpdates()
        shakeHandler = nil
    }

    // MARK: - Counted shake mode (shake N times to trigger)

    /// Start listening for shakes that count toward a target.
    /// Each valid shake (with cooldown) increments `shakeCount`.
    /// When `shakeCount` reaches `target`, calls `onComplete`.
    /// Each intermediate shake calls `onShake` for haptic feedback.
    func startCountedShakes(target: Int, onShake: @escaping () -> Void, onComplete: @escaping () -> Void) {
        guard motionManager.isAccelerometerAvailable else { return }
        shakeCount = 0
        lastShakeTime = .distantPast

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let magnitude = self.accelerationMagnitude(data.acceleration)
            let now = Date()

            if magnitude > self.shakeThreshold && now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                self.lastShakeTime = now
                self.shakeCount += 1
                onShake()

                if self.shakeCount >= target {
                    self.stopShakeDetection()
                    onComplete()
                }
            }
        }
    }

    func resetShakeCount() {
        shakeCount = 0
    }

    // MARK: - Private

    private func accelerationMagnitude(_ a: CMAcceleration) -> Double {
        sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    }
}
