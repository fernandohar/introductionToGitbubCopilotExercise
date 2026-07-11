# Game Catalog — Developer Guide

Games are split into two groups:

| Source | Shipped with app? | Examples |
|--------|-------------------|----------|
| `bundled` | Yes | Big Two, Blackjack |
| `downloadable` | No — fetched online | UNO Classic, The Simpsons UNO |

Players download extra games via **Settings → Get Latest Games** or the ↓ button on the game picker.

## Adding a shedding game (UNO-style)

```json
{
  "id": "uno-simpsons",
  "name": "The Simpsons UNO",
  "source": "downloadable",
  "engineType": "shedding",
  "sheddingDeck": {
    "startingHandSize": 7,
    "includeSkip": true,
    "includeReverse": true,
    "includeDrawTwo": true,
    "includeWild": true,
    "includeWildDrawFour": true
  },
  "sheddingTheme": {
    "red": { "color": "#FF6B35", "pattern": "diamonds" },
    "blue": { "color": "#4A90D9", "pattern": "dots" },
    "green": { "color": "#5CB85C", "pattern": "checkered" },
    "yellow": { "color": "#FFD90F", "pattern": "stripes" },
    "wild": { "color": "#1A1A1A", "pattern": "characters" },
    "cardBack": "#FFD90F",
    "faces": {
      "blue-skip": { "name": "Homer", "emoji": "🏃" },
      "wild-wild": { "name": "Homer", "emoji": "🍩" }
    }
  }
}
```

### Pattern types

`dots`, `checkered`, `stripes`, `diamonds`, `characters`, `solid`

### Character faces

Key format: `{colour}-{value}` e.g. `red-eight`, `wild-wildDrawFour`

Use emoji + name for themed card faces (no copyrighted images required).

## Publishing

1. Edit `GameCatalog/catalog.json` (online catalog — includes downloadable games)
2. Keep `UnoMultiplayer/Resources/GameCatalog/catalog.json` as bundled-only
3. Push to GitHub — players tap **Get Latest Games**
