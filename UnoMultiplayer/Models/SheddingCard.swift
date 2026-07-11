import Foundation

enum SheddingColor: String, Codable, CaseIterable, Hashable {
    case red, blue, green, yellow, wild

    var displayName: String { rawValue.capitalized }
}

enum SheddingValue: String, Codable, Hashable {
    case zero, one, two, three, four, five, six, seven, eight, nine
    case skip, reverse, drawTwo
    case wild, wildDrawFour

    var displayName: String {
        switch self {
        case .zero: "0"
        case .one: "1"
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .five: "5"
        case .six: "6"
        case .seven: "7"
        case .eight: "8"
        case .nine: "9"
        case .skip: "Skip"
        case .reverse: "Reverse"
        case .drawTwo: "+2"
        case .wild: "Wild"
        case .wildDrawFour: "+4"
        }
    }

    var isNumber: Bool {
        switch self {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine: true
        default: false
        }
    }
}

struct SheddingCard: Identifiable, Codable, Hashable {
    let id: UUID
    let color: SheddingColor
    let value: SheddingValue

    init(id: UUID = UUID(), color: SheddingColor, value: SheddingValue) {
        self.id = id
        self.color = color
        self.value = value
    }

    var isWild: Bool { value == .wild || value == .wildDrawFour }

    var faceKey: String {
        if isWild { return "wild-\(value.rawValue)" }
        return "\(color.rawValue)-\(value.rawValue)"
    }

    func matches(topCard: SheddingCard, activeColor: SheddingColor?) -> Bool {
        if isWild { return true }
        let effectiveColor = topCard.isWild ? (activeColor ?? topCard.color) : topCard.color
        return color == effectiveColor || value == topCard.value
    }
}

struct SheddingDeckConfig: Codable, Hashable {
    var startingHandSize: Int = 7
    var includeSkip: Bool = true
    var includeReverse: Bool = true
    var includeDrawTwo: Bool = true
    var includeWild: Bool = true
    var includeWildDrawFour: Bool = true
    var allowStackingDraws: Bool = false
}

struct SheddingSuitStyle: Codable, Hashable {
    var color: String
    var pattern: String
}

struct SheddingCharacterFace: Codable, Hashable {
    var name: String
    var emoji: String
}

struct SheddingTheme: Codable, Hashable {
    var red: SheddingSuitStyle
    var blue: SheddingSuitStyle
    var green: SheddingSuitStyle
    var yellow: SheddingSuitStyle
    var wild: SheddingSuitStyle
    var cardBack: String
    var faces: [String: SheddingCharacterFace]?

    func style(for color: SheddingColor) -> SheddingSuitStyle {
        switch color {
        case .red: red
        case .blue: blue
        case .green: green
        case .yellow: yellow
        case .wild: wild
        }
    }

    func face(for card: SheddingCard) -> SheddingCharacterFace? {
        faces?[card.faceKey]
    }

    static let classic = SheddingTheme(
        red: SheddingSuitStyle(color: "#E53935", pattern: "solid"),
        blue: SheddingSuitStyle(color: "#1E88E5", pattern: "solid"),
        green: SheddingSuitStyle(color: "#43A047", pattern: "solid"),
        yellow: SheddingSuitStyle(color: "#FDD835", pattern: "solid"),
        wild: SheddingSuitStyle(color: "#8E24AA", pattern: "solid"),
        cardBack: "#4A6FA5"
    )
}

struct SheddingDeck {
    private(set) var cards: [SheddingCard] = []

    init(config: SheddingDeckConfig, shuffled: Bool = true) {
        cards = Self.build(config: config)
        if shuffled { cards.shuffle() }
    }

    mutating func draw() -> SheddingCard? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    private static func build(config: SheddingDeckConfig) -> [SheddingCard] {
        var cards: [SheddingCard] = []
        let colors: [SheddingColor] = [.red, .blue, .green, .yellow]
        let numbers: [SheddingValue] = [.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine]

        for color in colors {
            for number in numbers {
                let count = number == .zero ? 1 : 2
                for _ in 0 ..< count { cards.append(SheddingCard(color: color, value: number)) }
            }
            if config.includeSkip {
                for _ in 0 ..< 2 { cards.append(SheddingCard(color: color, value: .skip)) }
            }
            if config.includeReverse {
                for _ in 0 ..< 2 { cards.append(SheddingCard(color: color, value: .reverse)) }
            }
            if config.includeDrawTwo {
                for _ in 0 ..< 2 { cards.append(SheddingCard(color: color, value: .drawTwo)) }
            }
        }
        if config.includeWild {
            for _ in 0 ..< 4 { cards.append(SheddingCard(color: .wild, value: .wild)) }
        }
        if config.includeWildDrawFour {
            for _ in 0 ..< 4 { cards.append(SheddingCard(color: .wild, value: .wildDrawFour)) }
        }
        return cards
    }
}
