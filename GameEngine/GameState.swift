import Foundation

// MARK: - Rock-Paper-Scissors Types

/// The three possible RPS choices.
enum RPSChoice: String, Codable, CaseIterable {
    case rock
    case paper
    case scissors

    var symbol: String {
        switch self {
        case .rock:     return "👊"
        case .paper:    return "✋"
        case .scissors: return "✌️"
        }
    }

    var label: String {
        switch self {
        case .rock:     return "Rock"
        case .paper:    return "Paper"
        case .scissors: return "Scissors"
        }
    }

    /// Image asset name (placeholder).
    var imageName: String { rawValue }

    /// Sound asset name (placeholder).
    var soundName: String { rawValue }

    /// Returns .win if self beats other, .lose if other beats self, .draw if equal.
    func outcome(against other: RPSChoice) -> RoundOutcome {
        if self == other { return .draw }
        switch (self, other) {
        case (.rock, .scissors), (.scissors, .paper), (.paper, .rock):
            return .win
        default:
            return .lose
        }
    }

    /// Secure, unbiased random generation using SystemRandomNumberGenerator.
    static func secureRandom() -> RPSChoice {
        var rng = SystemRandomNumberGenerator()
        return allCases.randomElement(using: &rng)!
    }
}

enum RoundOutcome: String, Codable {
    case win
    case lose
    case draw
}

/// The result of a single round, broadcast by the HOST after both players have chosen.
struct RoundResult: Codable, Equatable {
    let round: Int
    let hostChoice: RPSChoice
    let guestChoice: RPSChoice
    let winnerName: String?  // nil = draw

    static func determine(round: Int, hostChoice: RPSChoice, guestChoice: RPSChoice,
                          hostName: String, guestName: String) -> RoundResult {
        let outcome = hostChoice.outcome(against: guestChoice)
        let winner: String? = switch outcome {
        case .win:  hostName
        case .lose: guestName
        case .draw: nil
        }
        return RoundResult(round: round, hostChoice: hostChoice, guestChoice: guestChoice, winnerName: winner)
    }
}

// MARK: - Game State

/// Full match state. The HOST is the single source of truth.
struct GameState: Codable, Equatable {
    var hostName: String = ""
    var guestName: String = ""
    var currentRound: Int = 1
    let roundsToWin: Int = 2     // first to 2 wins (best of 3)
    var hostWins: Int = 0
    var guestWins: Int = 0
    var roundResults: [RoundResult] = []
    var isShakeModeEnabled: Bool = false

    /// Name of the match winner, or nil if match is still going.
    var matchWinner: String? {
        if hostWins >= roundsToWin { return hostName }
        if guestWins >= roundsToWin { return guestName }
        return nil
    }

    var isMatchOver: Bool { matchWinner != nil }
}

// MARK: - Game Phase

enum GamePhase: Equatable {
    case idle              // home screen / lobby
    case shakeReady        // shake mode: waiting for 3 shakes to begin
    case countdown(Int)    // 3-2-1 with "Rock" / "Paper" / "Scissors" text
    case choosing          // players pick rock/paper/scissors
    case reveal(RoundResult) // showing both choices + round winner
    case matchResult       // final scoreboard
}

/// The text shown during countdown ticks.
enum CountdownLabel: String {
    case rock = "Rock..."
    case paper = "Paper..."
    case scissors = "Scissors!"

    static func forTick(_ tick: Int) -> CountdownLabel {
        switch tick {
        case 3: return .rock
        case 2: return .paper
        default: return .scissors
        }
    }
}

// MARK: - Player Action

/// Actions a player can send during the choosing phase.
enum PlayerAction: Codable, Equatable {
    case chose(RPSChoice)
}
