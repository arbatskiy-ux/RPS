import CoreMotion
import Combine
import UIKit

/// Detects shake gestures via CoreMotion accelerometer (real device)
/// or UIKit motionBegan (Simulator fallback).
final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published private(set) var shakeCount: Int = 0

    private var shakeHandler: (() -> Void)?
    private var countedOnShake: (() -> Void)?
    private var countedOnComplete: (() -> Void)?
    private var countedTarget: Int = 0

    private var lastShakeTime: Date = .distantPast
    private let shakeThreshold: Double = 2.5
    private let updateInterval: TimeInterval = 0.05
    private let shakeCooldown: TimeInterval = 0.4

    // MARK: - Simulator detection

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Continuous shake detection

    func startShakeDetection(handler: @escaping () -> Void) {
        shakeHandler = handler
        if isSimulator { return }  // simulator uses UIKit path

        guard motionManager.isAccelerometerAvailable else { return }
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
        countedOnShake = nil
        countedOnComplete = nil
    }

    // MARK: - Counted shake mode

    func startCountedShakes(target: Int, onShake: @escaping () -> Void, onComplete: @escaping () -> Void) {
        shakeCount = 0
        lastShakeTime = .distantPast
        countedTarget = target
        countedOnShake = onShake
        countedOnComplete = onComplete

        if isSimulator { return }  // simulator uses UIKit path

        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let magnitude = self.accelerationMagnitude(data.acceleration)
            let now = Date()

            if magnitude > self.shakeThreshold && now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                self.lastShakeTime = now
                self.recordShake()
            }
        }
    }

    func resetShakeCount() {
        shakeCount = 0
    }

    // MARK: - UIKit shake (Simulator: Device → Shake or ⌃⌘Z)

    /// Call this from UIWindow.motionBegan — handles simulator shake events.
    func handleUIKitShake() {
        let now = Date()
        guard now.timeIntervalSince(lastShakeTime) > shakeCooldown else { return }
        lastShakeTime = now

        if countedOnShake != nil || countedOnComplete != nil {
            recordShake()
        } else {
            shakeHandler?()
        }
    }

    // MARK: - Private

    private func recordShake() {
        shakeCount += 1
        countedOnShake?()

        if shakeCount >= countedTarget {
            let completion = countedOnComplete
            stopShakeDetection()
            completion?()
        }
    }

    private func accelerationMagnitude(_ a: CMAcceleration) -> Double {
        sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    }
}
