# Game Catalog — Developer Guide

This folder contains the UNO game varieties that the iOS app downloads and displays.

## How it works

1. The app ships with a **bundled** copy at `UnoMultiplayer/Resources/GameCatalog/catalog.json`
2. Players tap **Settings → Get Latest Games** to fetch the newest catalog from GitHub
3. The default URL is:
   `https://raw.githubusercontent.com/fernandohar/uno-multiplayer-ios/main/GameCatalog/catalog.json`

## Adding a new UNO variety

Edit `catalog.json` and add a new entry to the `variants` array:

```json
{
  "id": "my-custom-uno",
  "name": "My Custom UNO",
  "tagline": "Short description shown in the picker",
  "icon": "🎴",
  "accentColor": "#FF5722",
  "rules": "Full rules shown before the game starts.\n\nUse \\n for line breaks.",
  "deck": {
    "allWild": false,
    "includeSkip": true,
    "includeReverse": true,
    "includeDrawTwo": true,
    "includeWild": true,
    "includeWildDrawFour": true,
    "allowStackingDraws": false,
    "startingHandSize": 7,
    "turnTimeLimit": 30,
    "readyTimeLimit": 300
  },
  "theme": {
    "red": "#E53935",
    "blue": "#1E88E5",
    "green": "#43A047",
    "yellow": "#FDD835",
    "wild": "#8E24AA",
    "cardStyle": "my-custom-uno"
  }
}
```

### Deck options

| Field | Description |
|-------|-------------|
| `allWild` | Every card is wild (like UNO All Wild!) |
| `allowStackingDraws` | Players can stack +2/+4 (No Mercy rules) |
| `turnTimeLimit` | Seconds per turn (default 30) |
| `readyTimeLimit` | Seconds before auto-start (default 300 = 5 min) |

### Card theme

The `theme` object controls card colors in the UI. Use hex colors (`#RRGGBB`).

The `cardStyle` field is a string identifier for future custom card art assets.

## Publishing updates

1. Commit changes to `GameCatalog/catalog.json`
2. Push to GitHub
3. Players open **Settings → Get Latest Games** in the app

No App Store update is required for new game varieties.
