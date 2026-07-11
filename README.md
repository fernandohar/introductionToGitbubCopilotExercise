# Uno Multiplayer (iOS)

A SwiftUI-based multiplayer Uno card game for iOS. Play with friends on the same Wi-Fi network using Apple's Multipeer Connectivity framework — no backend server required.

## Features

- **Local multiplayer** — Host or join games on the same network (2–10 players)
- **Full Uno rules** — Skip, Reverse, Draw Two, Wild, and Wild Draw Four
- **SwiftUI interface** — Lobby, game board, card hand, and color picker
- **Testable game engine** — Pure Swift logic separated from UI and networking

## Requirements

- macOS with **Xcode 15+**
- **iOS 17+** device or simulator (Multipeer Connectivity works best on physical devices)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Getting Started

### 1. Create the GitHub repository

On your Mac or in the GitHub web UI, create a new public or private repo named `uno-multiplayer-ios`.

**Option A — GitHub website**

1. Go to [github.com/new](https://github.com/new)
2. Repository name: `uno-multiplayer-ios`
3. Description: `Multiplayer Uno card game for iOS`
4. Choose Public or Private
5. Do **not** initialize with a README (this project already has one)
6. Click **Create repository**

**Option B — GitHub CLI**

```bash
gh repo create uno-multiplayer-ios --public --description "Multiplayer Uno card game for iOS"
```

### 2. Clone and generate the Xcode project

```bash
git clone https://github.com/YOUR_USERNAME/uno-multiplayer-ios.git
cd uno-multiplayer-ios

# Install XcodeGen if needed
brew install xcodegen

# Generate UnoMultiplayer.xcodeproj
xcodegen generate
```

### 3. Open in Xcode and run

```bash
open UnoMultiplayer.xcodeproj
```

1. Select your development team in **Signing & Capabilities**
2. Build and run on two physical iOS devices on the same Wi-Fi network
3. One player taps **Host Game**, others tap **Join Game**

## Project Structure

```
uno-multiplayer-ios/
├── project.yml              # XcodeGen project definition
├── UnoMultiplayer/
│   ├── Models/              # Card, Deck, Player, GameState
│   ├── Game/                # UnoEngine (rules and turn logic)
│   ├── Networking/          # GameSession protocol + MultipeerConnectivity
│   ├── ViewModels/          # GameViewModel
│   └── Views/               # LobbyView, GameView, CardView
└── UnoMultiplayerTests/     # Unit tests for game engine
```

## Architecture

| Layer | Responsibility |
|-------|----------------|
| **Models** | Data types for cards, players, and game state |
| **UnoEngine** | Rule validation, card play, draw pile, turn order |
| **GameSession** | Protocol abstracting multiplayer transport |
| **MultipeerGameSession** | Peer-to-peer networking via Multipeer Connectivity |
| **SwiftUI Views** | Lobby, game board, and player interactions |

## Roadmap

- [ ] Online multiplayer via WebSocket backend
- [ ] Game Center integration
- [ ] Animated card play and sound effects
- [ ] "Call Uno" penalty when a player forgets
- [ ] Custom house rules

## License

MIT License — see [LICENSE](LICENSE).
