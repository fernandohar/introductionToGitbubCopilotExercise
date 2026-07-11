# Card Cabana (iOS)

A relaxed, vacation-themed card game platform for iOS. Play classic games like **Big Two** (Cho Dai Di) and **Blackjack** — solo against NPCs or with friends nearby via Bluetooth/Wi-Fi (no internet required).

## Features

- **Game platform** — Not tied to any single branded card game; loads games from a JSON catalog
- **Big Two** — Hong Kong classic (Cho Dai Di / Dai Di) with standard 52-card deck
- **Blackjack** — Beat the dealer to 21
- **Vacation UI** — Light sand & ocean palette, soft palm-green table
- **Player seats** — NEXT badge on upcoming player, mini card-stack previews showing hand size
- **Single player** — Local NPC opponents with Easy / Medium / Hard difficulty
- **Multiplayer** — Create or join rooms offline (works on a plane)
- **Developer catalog** — Add games via `GameCatalog/catalog.json` on GitHub

## Game flow

```
Card Cabana Home
├── Single Player → Difficulty → Choose Game → Rules & 👌 Ready → Play
└── Multiplayer
    ├── Create Room → Choose Game → Lobby → Rules & Ready → Play
    └── Join Room → Lobby → Rules & Ready → Play
```

## Setup

```bash
brew install xcodegen
xcodegen generate
open UnoMultiplayer.xcodeproj
```

## Adding new games

See [GameCatalog/README.md](GameCatalog/README.md).

## License

MIT License — see [LICENSE](LICENSE).
