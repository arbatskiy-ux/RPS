import AVFoundation

/// Plays sound effects for countdown and game events.
/// Add actual .wav files to the Sounds/ directory to enable audio.
final class AudioManager {
    private var player: AVAudioPlayer?

    /// Plays a sound file from the Sounds/ directory.
    /// Filenames: "rock", "paper", "scissors", "countdown"
    func play(sound name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {}
    }

    /// Plays the appropriate sound for a countdown tick.
    func playCountdownSound(tick: Int) {
        switch tick {
        case 3: play(sound: "rock")
        case 2: play(sound: "paper")
        case 1: play(sound: "scissors")
        default: play(sound: "countdown")
        }
    }

    func stop() {
        player?.stop()
    }
}
