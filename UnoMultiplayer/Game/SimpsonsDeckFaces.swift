import Foundation

/// Complete Springfield character mapping for every card in The Simpsons UNO deck.
enum SimpsonsDeckFaces {
    static let all: [String: SheddingCharacterFace] = [
        // MARK: Blue — dot pattern
        "blue-zero": .init(name: "Smithers", emoji: "👔"),
        "blue-one": .init(name: "Homer", emoji: "🍺"),
        "blue-two": .init(name: "Bart", emoji: "🛹"),
        "blue-three": .init(name: "Milhouse", emoji: "👓"),
        "blue-four": .init(name: "Moe", emoji: "🍻"),
        "blue-five": .init(name: "Barney", emoji: "🍩"),
        "blue-six": .init(name: "Skinner", emoji: "🏫"),
        "blue-seven": .init(name: "Flanders", emoji: "⛪"),
        "blue-eight": .init(name: "Wiggum", emoji: "🚔"),
        "blue-nine": .init(name: "Comic Book Guy", emoji: "📚"),
        "blue-skip": .init(name: "Homer", emoji: "🏃"),
        "blue-reverse": .init(name: "Disco Stu", emoji: "🕺"),
        "blue-drawTwo": .init(name: "Sideshow Bob", emoji: "🎭"),

        // MARK: Green — checkered pattern
        "green-zero": .init(name: "Lisa", emoji: "🎷"),
        "green-one": .init(name: "Ralph", emoji: "🤪"),
        "green-two": .init(name: "Nelson", emoji: "👊"),
        "green-three": .init(name: "Krusty", emoji: "🤡"),
        "green-four": .init(name: "Lisa", emoji: "🎷"),
        "green-five": .init(name: "Maggie", emoji: "👶"),
        "green-six": .init(name: "SLH & Snowball", emoji: "🐶"),
        "green-seven": .init(name: "Apu", emoji: "🏪"),
        "green-eight": .init(name: "Otto", emoji: "🚌"),
        "green-nine": .init(name: "Willie", emoji: "🌿"),
        "green-skip": .init(name: "Lisa", emoji: "✋"),
        "green-reverse": .init(name: "Marge", emoji: "💙"),
        "green-drawTwo": .init(name: "Kang & Kodos", emoji: "👽"),

        // MARK: Yellow — stripe pattern
        "yellow-zero": .init(name: "Marge", emoji: "💇"),
        "yellow-one": .init(name: "Bart", emoji: "😈"),
        "yellow-two": .init(name: "Homer", emoji: "🛋️"),
        "yellow-three": .init(name: "Lisa", emoji: "📖"),
        "yellow-four": .init(name: "Bart", emoji: "🛹"),
        "yellow-five": .init(name: "Lisa", emoji: "🎵"),
        "yellow-six": .init(name: "Santa's Little Helper", emoji: "🐕"),
        "yellow-seven": .init(name: "Grampa", emoji: "👴"),
        "yellow-eight": .init(name: "Lenny & Carl", emoji: "🍻"),
        "yellow-nine": .init(name: "Professor Frink", emoji: "🔬"),
        "yellow-skip": .init(name: "Homer", emoji: "🏃"),
        "yellow-reverse": .init(name: "Bart", emoji: "🔄"),
        "yellow-drawTwo": .init(name: "Patty & Selma", emoji: "💨"),

        // MARK: Red — diamond pattern
        "red-zero": .init(name: "Marge", emoji: "💄"),
        "red-one": .init(name: "Homer", emoji: "😋"),
        "red-two": .init(name: "Marge", emoji: "💙"),
        "red-three": .init(name: "Homer", emoji: "🍩"),
        "red-four": .init(name: "Bart", emoji: "📺"),
        "red-five": .init(name: "Maggie", emoji: "🍼"),
        "red-six": .init(name: "SLH & Snowball", emoji: "🐱"),
        "red-seven": .init(name: "Burns", emoji: "☢️"),
        "red-eight": .init(name: "Mr. Burns", emoji: "💰"),
        "red-nine": .init(name: "Krusty", emoji: "🎪"),
        "red-skip": .init(name: "Homer", emoji: "😴"),
        "red-reverse": .init(name: "Bart", emoji: "🙃"),
        "red-drawTwo": .init(name: "Patty & Selma", emoji: "🚬"),

        // MARK: Wild cards — black sketch background
        "wild-wild": .init(name: "Homer", emoji: "🍩"),
        "wild-wildDrawFour": .init(name: "Ralph", emoji: "🌭")
    ]

    static let theme = SheddingTheme(
        red: SheddingSuitStyle(color: "#FF6B35", pattern: "diamonds"),
        blue: SheddingSuitStyle(color: "#4A90D9", pattern: "dots"),
        green: SheddingSuitStyle(color: "#5CB85C", pattern: "checkered"),
        yellow: SheddingSuitStyle(color: "#FFD90F", pattern: "stripes"),
        wild: SheddingSuitStyle(color: "#1A1A1A", pattern: "characters"),
        cardBack: "#FFD90F",
        faces: all,
        deckStyle: "simpsons",
        cardBackEmoji: "🍩",
        cardBackLabel: "Springfield",
        cardBackImage: "DeckArt/springfield/card-back",
        deckPreviewImage: "DeckArt/springfield/deck-preview"
    )

    static let rules = """
    THE SIMPSONS UNO — Official House Rules

    OBJECT
    Be the first Springfield resident to play every card in your hand.

    SETUP
    • 2–10 players
    • Deal 7 cards each
    • Flip the top draw-pile card to start the discard pile
    • If the first card is Wild or +4, return it to the deck and flip again

    ON YOUR TURN
    Play a card that matches the top card by COLOUR or NUMBER/SYMBOL.
    Or play a Wild card to change the colour.
    If you cannot play, draw 1 card. You may play it immediately if legal.

    CARD TYPES
    • Number cards (0–9) — Springfield characters on themed backgrounds
    • Skip 🏃 — The next player loses their turn (Homer naps through it)
    • Reverse 🔄 — Play direction reverses (Disco Stu says “Hey, disco!”)
    • Draw Two (+2) 💨 — Next player draws 2 and loses their turn (Patty & Selma special)
    • Wild 🍩 — Homer grabs a donut; you pick the next colour
    • Wild Draw Four (+4) 🌭 — Ralph's hot dogs; pick colour, next player draws 4

    COLOUR PATTERNS
    • Blue — polka dots (Evergreen Terrace cool tones)
    • Green — checkered (Lisa & family)
    • Yellow — diagonal stripes (Simpsons signature yellow)
    • Red — diamonds (Burns manor energy)
    • Wild — black card with Springfield character sketches

    ONE CARD LEFT!
    When you have exactly 1 card, tap "One left!" before the next player goes.
    If caught forgetting, draw 2 penalty cards.

    WINNING
    First player to discard their last card wins the round!

    TIE-BREAKER
    If the draw pile runs out, shuffle the discard pile (except the top card) to refresh it.
    """
}
