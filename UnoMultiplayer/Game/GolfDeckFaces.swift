import Foundation

/// Golf-themed character mapping for the Fairway Match deck.
enum GolfDeckFaces {
    static let all: [String: SheddingCharacterFace] = [
        // Blue — water hazard
        "blue-zero": .init(name: "Water Hazard", emoji: "💧"),
        "blue-one": .init(name: "Pond", emoji: "🌊"),
        "blue-two": .init(name: "Lake", emoji: "🏞️"),
        "blue-three": .init(name: "Stream", emoji: "〰️"),
        "blue-four": .init(name: "Splash", emoji: "💦"),
        "blue-five": .init(name: "Duck Pond", emoji: "🦆"),
        "blue-six": .init(name: "Rain Delay", emoji: "🌧️"),
        "blue-seven": .init(name: "Carry", emoji: "⛳"),
        "blue-eight": .init(name: "Bridge", emoji: "🌉"),
        "blue-nine": .init(name: "Island Green", emoji: "🏝️"),
        "blue-skip": .init(name: "Mulligan", emoji: "⏭️"),
        "blue-reverse": .init(name: "Backspin", emoji: "🔄"),
        "blue-drawTwo": .init(name: "Two Stroke", emoji: "+2"),

        // Green — fairway
        "green-zero": .init(name: "Fairway", emoji: "🌿"),
        "green-one": .init(name: "Tee Box", emoji: "📍"),
        "green-two": .init(name: "Approach", emoji: "🎯"),
        "green-three": .init(name: "Rough", emoji: "🌾"),
        "green-four": .init(name: "Divot", emoji: "🕳️"),
        "green-five": .init(name: "Caddie", emoji: "🧢"),
        "green-six": .init(name: "Cart Path", emoji: "🛒"),
        "green-seven": .init(name: "Chip Shot", emoji: "🏌️"),
        "green-eight": .init(name: "Birdie", emoji: "🐦"),
        "green-nine": .init(name: "Eagle", emoji: "🦅"),
        "green-skip": .init(name: "Skip Hole", emoji: "⏭️"),
        "green-reverse": .init(name: "Reverse Spin", emoji: "↩️"),
        "green-drawTwo": .init(name: "Penalty", emoji: "⚠️"),

        // Yellow — sunshine
        "yellow-zero": .init(name: "Sunrise", emoji: "🌅"),
        "yellow-one": .init(name: "Dawn Patrol", emoji: "☀️"),
        "yellow-two": .init(name: "Midday", emoji: "🌞"),
        "yellow-three": .init(name: "Golden Hour", emoji: "✨"),
        "yellow-four": .init(name: "Sunglasses", emoji: "🕶️"),
        "yellow-five": .init(name: "Sunscreen", emoji: "🧴"),
        "yellow-six": .init(name: "Ice Tea", emoji: "🍹"),
        "yellow-seven": .init(name: "Hole in One", emoji: "1️⃣"),
        "yellow-eight": .init(name: "Trophy", emoji: "🏆"),
        "yellow-nine": .init(name: "Champion", emoji: "🥇"),
        "yellow-skip": .init(name: "Rain Check", emoji: "☂️"),
        "yellow-reverse": .init(name: "U-Turn", emoji: "🔃"),
        "yellow-drawTwo": .init(name: "Double Bogey", emoji: "+2"),

        // Red — sand trap
        "red-zero": .init(name: "Bunker", emoji: "🏖️"),
        "red-one": .init(name: "Sand Wedge", emoji: "⛳"),
        "red-two": .init(name: "Rake", emoji: "🧹"),
        "red-three": .init(name: "Grit", emoji: "🪣"),
        "red-four": .init(name: "Buried Lie", emoji: "⬇️"),
        "red-five": .init(name: "Explosion", emoji: "💥"),
        "red-six": .init(name: "Lip Out", emoji: "😤"),
        "red-seven": .init(name: "Escape", emoji: "🚀"),
        "red-eight": .init(name: "Greenside", emoji: "🚩"),
        "red-nine": .init(name: "Clubhouse", emoji: "🏠"),
        "red-skip": .init(name: "Lost Ball", emoji: "🔍"),
        "red-reverse": .init(name: "Hook", emoji: "🪝"),
        "red-drawTwo": .init(name: "Out of Bounds", emoji: "🚫"),

        // Wild
        "wild-wild": .init(name: "Wild Shot", emoji: "⛳"),
        "wild-wildDrawFour": .init(name: "Four Penalty", emoji: "+4")
    ]

    static let theme = SheddingTheme(
        red: SheddingSuitStyle(color: "#C4A882", pattern: "diamonds"),
        blue: SheddingSuitStyle(color: "#4A90D9", pattern: "dots"),
        green: SheddingSuitStyle(color: "#2D6A4F", pattern: "stripes"),
        yellow: SheddingSuitStyle(color: "#F4D35E", pattern: "checkered"),
        wild: SheddingSuitStyle(color: "#1A1A1A", pattern: "characters"),
        cardBack: "#2D6A4F",
        faces: all,
        deckStyle: "golf",
        cardBackEmoji: "⛳",
        cardBackLabel: "Fairway Match",
        cardBackImage: "DeckArt/golf/card-back",
        deckPreviewImage: "DeckArt/golf/deck-preview"
    )

    static let rules = """
    FAIRWAY MATCH — Golf House Rules

    OBJECT
    Be the first player to play every card in your hand.

    SETUP
    • 2–10 players
    • Deal 7 cards each
    • Flip the top draw-pile card to start play
    • If the first card is Wild or +4, reshuffle and flip again

    ON YOUR TURN
    Play a card matching the top card by COLOUR or NUMBER/SYMBOL.
    Or play a Wild to change the colour.
    If you cannot play, draw 1 card.

    CARD TYPES
    • Number cards (0–9) — golf course themed
    • Skip ⏭️ — Mulligan: next player loses their turn
    • Reverse 🔄 — Backspin: reverse play direction
    • Draw Two (+2) — Penalty strokes: next player draws 2
    • Wild ⛳ — Wild Shot: pick the next colour
    • Wild Draw Four (+4) — Four Penalty: pick colour, next draws 4

    COLOUR THEMES
    • Blue — water hazard (dots)
    • Green — fairway (stripes)
    • Yellow — sunshine (checkered)
    • Red — sand trap (diamonds)
    • Wild — black card with golf icons

    ONE CARD LEFT!
    Tap "One left!" when you have exactly 1 card.
    Forget and draw 2 penalty cards.

    WINNING
    First player to empty their hand wins the round!
    """
}
