import Foundation

struct GameState: Codable, Equatable {
    var scores: [String: Int] = [:]
    var round: Int = 1
    var timeRemaining: TimeInterval = 60
}

enum GamePhase: Equatable {
    case idle
    case countdown(Int)
    case playing
    case results
}

enum PlayerAction: Codable {
    case tap
    case shake
}
