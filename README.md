# Uno Multiplayer (iOS)

A SwiftUI-based UNO card game for iOS with single-player NPC mode, offline Bluetooth/Wi-Fi multiplayer, and downloadable game varieties from GitHub.

## Features

- **Home screen** — Single Player or Multiplayer
- **Single player** — Play against 1–3 local NPCs with Easy / Medium / Hard difficulty (offline)
- **Multiplayer** — Create or join a room; works offline via Bluetooth & Wi-Fi (great on a plane)
- **8 UNO varieties** — Classic, All Wild, Golf, Dare, Flex, No Mercy, Toy Story, X Games
- **Rules screen** — Everyone reads rules and taps 👌 Ready before the game starts
- **5-minute ready countdown** — Auto-starts if players don't ready up in time
- **30-second turn timer** — Auto-draws if a player runs out of time
- **Developer catalog** — Add new UNO games via `GameCatalog/catalog.json` on GitHub; players fetch updates in Settings

## Game Flow

```
Home
├── Single Player → Difficulty & NPC count → Pick UNO variety → Rules & Ready → Game
└── Multiplayer
    ├── Create Room → Pick UNO variety → Lobby → Rules & Ready → Game
    └── Join Room → Lobby → Rules & Ready → Game
```

## Requirements

- macOS with **Xcode 15+**
- **iOS 17+** (physical devices recommended for Bluetooth multiplayer)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```bash
git clone https://github.com/YOUR_USERNAME/uno-multiplayer-ios.git
cd uno-multiplayer-ios
brew install xcodegen
xcodegen generate
open UnoMultiplayer.xcodeproj
```

## Adding New UNO Varieties

See [GameCatalog/README.md](GameCatalog/README.md). Edit `GameCatalog/catalog.json`, push to GitHub, then tap **Settings → Get Latest Games** in the app.

## Project Structure

```
uno-multiplayer-ios/
├── GameCatalog/              # Remote game definitions (GitHub-hosted)
├── UnoMultiplayer/
│   ├── Models/               # Card, Deck, Player, GameState, UnoVariant
│   ├── Game/                 # UnoEngine, NPCPlayer AI
│   ├── Networking/           # LocalGameSession, MultipeerGameSession
│   ├── Services/             # GameCatalogService
│   ├── ViewModels/           # AppViewModel
│   ├── Views/                # Home, Setup, Variety, Rules, Lobby, Game
│   └── Resources/GameCatalog # Bundled catalog fallback
└── UnoMultiplayerTests/
```

## Architecture

| Layer | Responsibility |
|-------|----------------|
| **UnoVariant** | Rules, deck config, card theme per UNO variety |
| **GameCatalogService** | Bundled + remote catalog from GitHub |
| **UnoEngine** | Rule validation with per-variant deck config |
| **NPCPlayer** | Local AI with 3 difficulty levels |
| **MultipeerGameSession** | Offline P2P via Bluetooth/Wi-Fi |
| **AppViewModel** | Navigation, timers (30s turn, 5min ready) |

## License

MIT License — see [LICENSE](LICENSE).
