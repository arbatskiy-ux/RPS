import Foundation

/// Wire protocol for all peer-to-peer messages.
struct GameMessage: Codable {
    let senderName: String
    let payload: Payload

    enum Payload: Codable {
        case gameStarted
        case gameEnded
        case playerAction(PlayerAction)
        case stateSync(GameState)
    }
}
