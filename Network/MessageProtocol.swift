import Foundation

/// Wire protocol for all peer-to-peer messages.
/// Only the HOST sends control messages (.gameStarted, .gameEnded, .roundCountdown, .newMove, .stateSync).
/// Both HOST and GUEST send .playerAction to report their input.
struct GameMessage: Codable {
    let senderName: String
    let payload: Payload

    enum Payload: Codable {
        // HOST → GUEST: session control
        case gameStarted(GameState)
        case gameEnded(GameState)
        case roundCountdown(Int)

        // HOST → GUEST: authoritative state
        case stateSync(GameState)
        case newMove(Move)

        // Both directions: player input
        case playerAction(PlayerAction)
    }
}
