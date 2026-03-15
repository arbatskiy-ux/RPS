import CoreMotion
import UIKit

/// Detects shake gestures via CoreMotion accelerometer.
final class MotionManager {
    private let motionManager = CMMotionManager()
    private var shakeHandler: (() -> Void)?

    private let shakeThreshold: Double = 2.5
    private let updateInterval: TimeInterval = 0.05

    func startShakeDetection(handler: @escaping () -> Void) {
        guard motionManager.isAccelerometerAvailable else { return }
        shakeHandler = handler
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let acceleration = data.acceleration
            let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
            if magnitude > (self?.shakeThreshold ?? 2.5) {
                self?.shakeHandler?()
            }
        }
    }

    func stopShakeDetection() {
        motionManager.stopAccelerometerUpdates()
        shakeHandler = nil
    }
}
