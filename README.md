# PeerPlay

A modular peer-to-peer iOS game built with SwiftUI, MultipeerConnectivity, CoreHaptics, and CoreMotion.

## Architecture

```
PeerPlay/
├── App/                  # Entry point & global state
│   ├── PeerPlayApp.swift     — @main, App Scene
│   └── AppState.swift        — ObservableObject owning all managers
│
├── Views/                # SwiftUI presentation layer
│   ├── ContentView.swift     — Root screen router
│   ├── LobbyView.swift       — Peer discovery & connection
│   ├── GameView.swift        — In-game screen
│   └── Components/           — Reusable UI components
│
├── GameEngine/           # Pure game logic (no UI, no network details)
│   ├── GameEngine.swift      — Orchestrates state, events, feedback
│   ├── GameState.swift       — Value types: GameState, GamePhase, PlayerAction
│   └── (add game-specific logic here)
│
├── Network/              # MultipeerConnectivity abstraction
│   ├── MultipeerSession.swift — MCSession + advertiser + browser
│   └── MessageProtocol.swift  — Codable GameMessage wire format
│
└── DeviceManagers/       # Hardware abstraction
    ├── HapticManager.swift   — CoreHaptics with UIKit fallback
    └── MotionManager.swift   — CoreMotion shake detection
```

## Module responsibilities

| Module | Responsibility |
|---|---|
| `App` | Wires everything together; owns the dependency graph |
| `Views` | Renders state; delegates actions to GameEngine/Session |
| `GameEngine` | Processes actions, maintains scores, triggers haptics |
| `Network` | Sends/receives `GameMessage` over MultipeerConnectivity |
| `DeviceManagers` | Wraps platform APIs (haptics, motion) behind simple interfaces |

## Requirements

- iOS 16+
- Xcode 15+
- Physical devices for MultipeerConnectivity testing (simulator has limited support)

## Getting started

1. Open `PeerPlay.xcodeproj` in Xcode (create via File → New → Project, then add these sources)
2. Add capabilities: **Wireless Accessory Configuration** is not needed; add **Multipeer Connectivity** usage description to `Info.plist`
3. Build & run on two physical devices on the same Wi-Fi / Bluetooth

## Info.plist keys required

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to connect with nearby players</string>
<key>NSBonjourServices</key>
<array>
    <string>_peerplay-game._tcp</string>
    <string>_peerplay-game._udp</string>
</array>
```
