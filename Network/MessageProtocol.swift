import Foundation

/// Wire protocol for all peer-to-peer messages.
/// HOST sends control messages; both sides send player actions.
struct GameMessage: Codable {
    let senderName: String
    let payload: Payload

    enum Payload: Codable {
        // HOST → GUEST: session control
        case gameStarted(GameState)       // match begins
        case roundCountdown(Int)          // 3, 2, 1
        case startChoosing                // players may now pick
        case roundResult(RoundResult)     // reveal both choices + winner
        case matchEnded(GameState)        // final state with winner

        // HOST → GUEST: authoritative state
        case stateSync(GameState)

        // Both directions: player input
        case playerChoice(RPSChoice)      // player picked rock/paper/scissors
    }
}
