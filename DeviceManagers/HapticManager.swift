import CoreHaptics
import UIKit

/// Provides haptic feedback using CoreHaptics with UIKit fallback.
final class HapticManager {
    private var engine: CHHapticEngine?

    init() {
        prepareEngine()
    }

    // MARK: - Public API

    /// Light tap — used for countdown ticks and winner confirmation.
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if engine != nil {
            playCustomImpact(intensity: style == .light ? 0.4 : 0.8,
                             sharpness: style == .light ? 0.3 : 0.7)
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

    /// Short haptic pulse for countdown: "Rock" / "Paper" / "Scissors".
    func playCountdownPulse() {
        playCustomImpact(intensity: 0.6, sharpness: 0.5)
    }

    /// Winner: single light confirmation vibration.
    func playWinnerFeedback() {
        let events = [
            makeEvent(type: .hapticTransient, intensity: 0.5, sharpness: 0.3, time: 0)
        ]
        play(events: events)
    }

    /// Loser: 4x strong vibration with 0.4s pauses.
    /// Pattern: strong pulse → 0.4s pause → strong pulse → 0.4s pause → ... (4 times)
    func playLoserFeedback() {
        var events: [CHHapticEvent] = []
        let pulseDuration: TimeInterval = 0.15
        let pauseDuration: TimeInterval = 0.4
        let interval = pulseDuration + pauseDuration

        for i in 0..<4 {
            let time = TimeInterval(i) * interval
            events.append(makeEvent(type: .hapticContinuous, intensity: 1.0, sharpness: 0.8,
                                    time: time, duration: pulseDuration))
        }
        play(events: events)
    }

    /// Haptic pulse for shake detection. Intensity grows with shake count (1→2→3).
    func playShakePulse(shakeNumber: Int = 1) {
        let intensity = Float(min(0.5 + Double(shakeNumber) * 0.2, 1.0))
        let sharpness = Float(min(0.4 + Double(shakeNumber) * 0.15, 0.9))
        playCustomImpact(intensity: intensity, sharpness: sharpness)
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

    private func makeEvent(type: CHHapticEvent.EventType,
                           intensity: Float, sharpness: Float,
                           time: TimeInterval, duration: TimeInterval = 0) -> CHHapticEvent {
        let params = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
        if type == .hapticContinuous {
            return CHHapticEvent(eventType: type, parameters: params,
                                relativeTime: time, duration: duration)
        }
        return CHHapticEvent(eventType: type, parameters: params, relativeTime: time)
    }

    private func playCustomImpact(intensity: Float, sharpness: Float) {
        let event = makeEvent(type: .hapticTransient, intensity: intensity, sharpness: sharpness, time: 0)
        play(events: [event])
    }

    private func playCustomNotification() {
        var events: [CHHapticEvent] = []
        for (index, intensity) in [1.0, 0.5, 0.8].enumerated() {
            events.append(makeEvent(type: .hapticTransient,
                                    intensity: Float(intensity), sharpness: 0.5,
                                    time: TimeInterval(index) * 0.1))
        }
        play(events: events)
    }

    private func play(events: [CHHapticEvent]) {
        guard let engine else {
            // Fallback: UIKit must run on main thread
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Engine might have stopped — restart and retry once
            try? engine.start()
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }
}
