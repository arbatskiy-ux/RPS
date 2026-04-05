# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build for simulator
xcodebuild -scheme RPS -destination 'platform=iOS Simulator,id=<UDID>' -configuration Debug build

# Get booted simulator UDID
xcrun simctl list devices booted

# Install + launch
xcrun simctl install <UDID> /path/to/DerivedData/.../RPS.app
xcrun simctl launch --terminate-running-process <UDID> com.arbatskiy.rps

# Screenshot
xcrun simctl io <UDID> screenshot /tmp/rps.png
```

DerivedData path: `~/Library/Developer/Xcode/DerivedData/RPS-*/Build/Products/Debug-iphonesimulator/RPS.app`

No unit tests exist in this project.

## Worktree + Main Repo

This project uses git worktrees. **Build always reads from the main repo**, not the worktree:
- Main repo: `/Users/sasha/Yandex.Disk-soyer-tom.localized/Vibecoding/RPS/`
- Worktree: `.claude/worktrees/<name>/`

**Always edit files in the main repo**, then copy to worktree and commit from main repo on branch `experiment/new-design`.

```bash
cp MainRepo/Views/Foo.swift Worktree/Views/Foo.swift
cd MainRepo && git add Views/Foo.swift && git commit
```

## Architecture

`AppState` (ObservableObject, injected as `@EnvironmentObject`) owns all singletons and drives screen routing via `currentScreen: Screen`. It subscribes to `GameEngine.$phase` and automatically transitions between screens.

**Screen flow:** `onboarding → home → connection → game → results`

`GameEngine` is HOST-authoritative: only the host runs the round loop, decides winners (using `SystemRandomNumberGenerator`), and broadcasts results. The guest is purely reactive.

**GamePhase state machine:**
```
idle → shakeReady → countdown → choosing → reveal → matchResult → idle
```
Phase changes are published via `@Published var phase: GamePhase` and drive which sub-view `GameView` renders.

**GameView sub-views by phase:**
- `.countdown` → full-screen `CountdownOverlayView` (color-coded per tick: green=3, purple=2, red=1)
- `.choosing` → `RPSChoiceButtons`
- `.reveal` → full-screen `RevealView` (win/lose result for the round)
- `.matchResult` → triggers `AppState` to switch to `ResultsView`

**Network:** `MultipeerSession` wraps `MCSession`. All messages are `GameMessage` with a `Payload` enum (Codable). HOST sends control messages; both sides send `playerChoice`.

**Debug previews:** Inject mock state via `GameEngine.previewState` and return a specific view directly in `ContentView.body`. The switch statement below becomes unreachable — restore it when done.

```swift
// ContentView.swift debug pattern:
var body: some View {
    let result = RoundResult(round: 1, hostChoice: .rock, guestChoice: .scissors, winnerName: "Майк")
    var s = GameState(); s.hostName = "Майк"; s.guestName = "Игрок"
    return RevealView(result: result, state: s, isHost: true).ignoresSafeArea()
    // unreachable switch below...
}
```

## Key Files

| File | Role |
|---|---|
| `App/AppState.swift` | Dependency graph, screen routing, avatar exchange |
| `GameEngine/GameEngine.swift` | HOST round loop, choice collection, winner logic |
| `GameEngine/GameState.swift` | `RPSChoice`, `RoundResult`, `GamePhase`, `GameState` |
| `Network/MessageProtocol.swift` | Complete wire protocol (all message types) |
| `Views/GameView.swift` | Game screen + `CountdownOverlayView` + `RevealView` |
| `Views/ResultsView.swift` | Match end screen with overlapping player cards + round history |

## iOS 26 Simulator Notes

- SwiftUI `Text` with emoji renders as placeholder boxes in iOS 26 simulator
- `UILabel` and `UIGraphicsImageRenderer` have the same issue
- Use **SF Symbols** instead: `hand.fist.fill` (rock), `hand.raised.fill` (paper), `scissors` (scissors)
- `simctl screenshot` accurately reflects actual rendering
