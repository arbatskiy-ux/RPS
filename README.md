# RPS — Rock Paper Scissors

A peer-to-peer Rock-Paper-Scissors game for iOS built with SwiftUI, MultipeerConnectivity, CoreHaptics, and CoreMotion.

## Game Rules

- Two players play Rock-Paper-Scissors over local network (Bluetooth/Wi-Fi)
- Best of 3 — first to win 2 rounds wins the match
- Draws replay the round without advancing the counter

## Screens

| Screen | Description |
|---|---|
| **Home** | Main menu with "Find Player" button |
| **Connection** | Shows nearby players, connection status, host/join, shake mode toggle |
| **Game** | Countdown ("Rock... Paper... Scissors!"), choosing, reveal |
| **Result** | Match winner, round-by-round history with symbols |

## Round Flow

```
Players connected → HOST starts game
        ↓
  [Shake Mode?] → Each player shakes 3 times to begin
        ↓
  Countdown: "Rock..." (3) → "Paper..." (2) → "Scissors!" (1)
  + haptic pulse each tick
        ↓
  Both players choose (5s timer, random if timeout)
        ↓
  HOST determines winner (secure random for timeouts)
        ↓
  Symbols displayed on both devices (same result)
        ↓
  Winner: light confirmation vibration
  Loser: 4x strong pulse (0.4s pauses)
        ↓
  Next round (or match results)
```

## Architecture

```
RPS/
├── App/
│   ├── RPSApp.swift             — @main entry point
│   └── AppState.swift           — Screen routing, dependency graph
├── Views/
│   ├── ContentView.swift        — Screen router
│   ├── HomeView.swift           — Home Screen (Find Player)
│   ├── ConnectionView.swift     — Connection Screen (host/join/status)
│   ├── GameView.swift           — Game Screen (countdown, choosing, reveal, shake mode)
│   ├── ResultsView.swift        — Result Screen (winner, round history)
│   └── Components/
│       ├── ActionButton.swift
│       ├── PeerListView.swift
│       └── PlayerNameField.swift
├── GameEngine/
│   ├── GameEngine.swift         — HOST-authoritative game loop
│   ├── GameState.swift          — RPSChoice, RoundResult, GamePhase, CountdownLabel
│   └── RoundTimer.swift         — Countdown timer with Combine
├── Network/
│   ├── MultipeerSession.swift   — MCSession + roles (host/guest)
│   └── MessageProtocol.swift    — Codable wire protocol
├── DeviceManagers/
│   ├── HapticManager.swift      — CoreHaptics (winner/loser/countdown patterns)
│   ├── MotionManager.swift      — CoreMotion (shake detection + counted shakes)
│   └── AudioManager.swift       — AVAudioPlayer for sound effects
├── Assets.xcassets/
│   ├── rock.imageset/rock.png   — placeholder
│   ├── paper.imageset/paper.png — placeholder
│   ├── scissors.imageset/scissors.png — placeholder
│   └── AppIcon.appiconset/app_icon.png — placeholder
└── Sounds/
    ├── rock.wav                 — placeholder
    ├── paper.wav                — placeholder
    ├── scissors.wav             — placeholder
    └── countdown.wav            — placeholder
```

## Haptic Feedback

| Event | Pattern |
|---|---|
| Countdown tick | Short pulse (medium intensity) |
| Player chooses | Medium impact |
| Shake detected | Short pulse |
| **Winner** | Single light confirmation tap |
| **Loser** | 4× strong vibration, 0.4s pause between each |

## Requirements

- iOS 16+, Xcode 15+
- Two physical devices (simulator has limited MultipeerConnectivity support)

## Setup

1. Create Xcode project, add source files
2. Replace placeholder images in `Assets.xcassets/` with actual artwork
3. Replace placeholder `.wav` files in `Sounds/` with actual audio
4. Add to `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to connect with nearby players</string>
<key>NSBonjourServices</key>
<array>
    <string>_rps-game._tcp</string>
    <string>_rps-game._udp</string>
</array>
```

5. Build & run on two physical devices on the same Wi-Fi / Bluetooth
