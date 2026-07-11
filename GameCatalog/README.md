# Game Catalog — Developer Guide

This folder defines the card games that **Card Cabana** loads and displays.

## How it works

1. The app ships with a bundled copy at `UnoMultiplayer/Resources/GameCatalog/catalog.json`
2. Players tap **Settings → Get Latest Games** to fetch updates from GitHub
3. Each game entry specifies its **engine**, **rules**, and **theme**

## Adding a new game

Edit `catalog.json` and add an entry to the `games` array:

```json
{
  "id": "my-game",
  "name": "My Card Game",
  "tagline": "Short description for the picker",
  "icon": "🎴",
  "accentColor": "#2A9D8F",
  "rules": "Full rules shown before the game.\n\nUse \\n for line breaks.",
  "engineType": "bigTwo",
  "settings": {
    "minPlayers": 2,
    "maxPlayers": 4,
    "turnTimeLimit": 30,
    "readyTimeLimit": 300
  },
  "theme": {
    "hearts": "#E63946",
    "diamonds": "#E63946",
    "clubs": "#1D3557",
    "spades": "#1D3557",
    "cardBack": "#4A6FA5",
    "tableFelt": "#8FBC8F"
  }
}
```

### Engine types

| `engineType` | Games |
|--------------|-------|
| `bigTwo` | Big Two (Cho Dai Di), climbing card games |
| `blackjack` | Blackjack (21) |

New engines can be added in `UnoMultiplayer/Game/` and registered in `GameEngineRouter.swift`.

## Publishing updates

1. Commit changes to `GameCatalog/catalog.json`
2. Push to GitHub
3. Players open **Settings → Get Latest Games**

No App Store update required for new game definitions.
