import CoreHaptics
import UIKit

/// Provides haptic feedback using CoreHaptics with UIKit fallback.
final class HapticManager {
    private var engine: CHHapticEngine?

    init() {
        prepareEngine()
    }

    // MARK: - Public API

    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if engine != nil {
            playCustomImpact()
        } else {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        if engine != nil {
            playCustomNotification()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }

    // MARK: - Private

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        } catch {
            engine = nil
        }
    }

    private func playCustomImpact() {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
        play(events: [event])
    }

    private func playCustomNotification() {
        var events: [CHHapticEvent] = []
        for (index, intensity) in [1.0, 0.5, 0.8].enumerated() {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
            events.append(CHHapticEvent(eventType: .hapticTransient,
                                        parameters: [sharpness, intensityParam],
                                        relativeTime: TimeInterval(index) * 0.1))
        }
        play(events: events)
    }

    private func play(events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }
}
