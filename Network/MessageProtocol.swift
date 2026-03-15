import Foundation

/// Wire protocol for all peer-to-peer messages.
/// HOST sends control messages; both sides send player actions.
struct GameMessage: Codable {
    let senderName: String
    let payload: Payload

    enum Payload: Codable {
        // HOST → GUEST: session control
        case gameStarted(GameState)       // match begins (includes shake mode flag)
        case roundCountdown(Int)          // 3 ("Rock"), 2 ("Paper"), 1 ("Scissors")
        case startChoosing                // players may now pick
        case roundResult(RoundResult)     // reveal both choices + winner
        case matchEnded(GameState)        // final state with winner

        // HOST → GUEST: authoritative state
        case stateSync(GameState)

        // HOST → GUEST: shake mode
        case shakePhaseStarted            // enter shake-to-start mode
        case shakePhaseCompleted          // host finished shaking, starting countdown

        // Both directions: player input
        case playerChoice(RPSChoice)      // player picked rock/paper/scissors
        case playerShakeReady             // GUEST tells HOST they finished shaking
    }
}
