# Game Catalog — Developer Guide

Games are split into two groups:

| Source | Shipped with app? | Examples |
|--------|-------------------|----------|
| `bundled` | Yes | Big Two, Blackjack |
| `downloadable` | No — fetched online | Colour Match Classic, Springfield, Fairway Match, Show No Mercy |

Players download extra games via **Settings → Get Latest Games** or the ↓ button on the game picker.

## JSON vs Lua for rules

**Use JSON** for shedding game rules in Card Cabana.

| | JSON | Lua |
|---|------|-----|
| iOS integration | Native `Codable` — no extra runtime | Needs Lua VM embed + sandbox |
| Downloadable mods | Safe data-only catalog | Code execution risk |
| Rule style | Declarative flags + numbers | Imperative scripts |
| Best for | `maxHandBeforeElimination`, stacking toggles, penalties | Custom mini-games outside the engine |

The Swift `SheddingEngine` interprets `sheddingRules` from JSON. Human-readable rule text stays in the `rules` string for the Rules screen.

### `sheddingRules` schema

```json
{
  "sheddingRules": {
    "profile": "showNoMercy",
    "maxHandBeforeElimination": 21,
    "allowStackingDraws": true,
    "requireOneLeftCall": true,
    "oneLeftPenaltyCards": 2,
    "jumpInEnabled": true,
    "sevenZeroEnabled": true
  }
}
```

| Field | Purpose |
|-------|---------|
| `profile` | Preset id: `classic`, `showNoMercy`, `golf` |
| `maxHandBeforeElimination` | Player eliminated when hand exceeds this (Show No Mercy: 21) |
| `allowStackingDraws` | Stack +2 / +4 penalties |
| `requireOneLeftCall` | Must tap "One left!" with 1 card |
| `oneLeftPenaltyCards` | Penalty draw count (default 2) |
| `jumpInEnabled` | Reserved — play exact match out of turn |
| `sevenZeroEnabled` | Reserved — swap on 7, rotate on 0 |

## Adding a shedding game

```json
{
  "id": "fairway-match",
  "name": "Fairway Match",
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
  "sheddingRules": { "profile": "golf", "requireOneLeftCall": true },
  "sheddingTheme": {
    "red": { "color": "#C4A882", "pattern": "diamonds" },
    "blue": { "color": "#4A90D9", "pattern": "dots" },
    "green": { "color": "#2D6A4F", "pattern": "stripes" },
    "yellow": { "color": "#F4D35E", "pattern": "checkered" },
    "wild": { "color": "#1A1A1A", "pattern": "characters" },
    "cardBack": "#2D6A4F",
    "deckStyle": "golf",
    "cardBackImage": "DeckArt/golf/card-back",
    "deckPreviewImage": "DeckArt/golf/deck-preview"
  }
}
```

### Pattern types

`dots`, `checkered`, `stripes`, `diamonds`, `characters`, `solid`

### Deck art assets

Place PNGs in `UnoMultiplayer/Resources/DeckArt/{deck}/`:

- `card-back.png` — card rear artwork
- `deck-preview.png` — rules-screen showcase sheet

Reference without extension: `"cardBackImage": "DeckArt/golf/card-back"`

Bundled Swift enums (`SimpsonsDeckFaces`, `GolfDeckFaces`) supply character faces when JSON `faces` is incomplete.

## Publishing

1. Edit `GameCatalog/catalog.json` (online catalog — includes downloadable games)
2. Keep `UnoMultiplayer/Resources/GameCatalog/catalog.json` as bundled-only
3. Push to GitHub — players tap **Get Latest Games**
