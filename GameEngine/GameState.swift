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

    static func random() -> RPSChoice {
        allCases.randomElement()!
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
    case idle              // in lobby
    case countdown(Int)    // 3-2-1 before each round
    case choosing          // players pick rock/paper/scissors
    case reveal(RoundResult) // showing both choices + round winner
    case matchResult       // final scoreboard
}

// MARK: - Player Action

/// Actions a player can send during the choosing phase.
enum PlayerAction: Codable, Equatable {
    case chose(RPSChoice)
}
