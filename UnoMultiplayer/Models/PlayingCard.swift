import Foundation

enum CardSuit: String, Codable, CaseIterable, Hashable {
    case spades, hearts, diamonds, clubs

    var symbol: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }

    /// Big Two suit order: diamonds lowest, spades highest
    var bigTwoPower: Int {
        switch self {
        case .diamonds: 0
        case .clubs: 1
        case .hearts: 2
        case .spades: 3
        }
    }
}

enum PlayingRank: String, Codable, CaseIterable, Hashable {
    case three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace, two

    var displayName: String {
        switch self {
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        case .ace: "A"
        case .two: "2"
        default: rawValue.capitalized
        }
    }

    var blackjackValue: Int {
        switch self {
        case .two: 2
        case .three: 3
        case .four: 4
        case .five: 5
        case .six: 6
        case .seven: 7
        case .eight: 8
        case .nine: 9
        case .ten, .jack, .queen, .king: 10
        case .ace: 11
        }
    }

    /// Big Two rank order: 3 lowest, 2 highest
    var bigTwoPower: Int {
        switch self {
        case .three: 0
        case .four: 1
        case .five: 2
        case .six: 3
        case .seven: 4
        case .eight: 5
        case .nine: 6
        case .ten: 7
        case .jack: 8
        case .queen: 9
        case .king: 10
        case .ace: 11
        case .two: 12
        }
    }
}

struct PlayingCard: Identifiable, Codable, Hashable {
    let id: UUID
    let suit: CardSuit
    let rank: PlayingRank

    init(id: UUID = UUID(), suit: CardSuit, rank: PlayingRank) {
        self.id = id
        self.suit = suit
        self.rank = rank
    }

    var bigTwoPower: Int { rank.bigTwoPower * 10 + suit.bigTwoPower }

    func beats(_ other: PlayingCard) -> Bool {
        bigTwoPower > other.bigTwoPower
    }

    var isThreeOfDiamonds: Bool {
        suit == .diamonds && rank == .three
    }
}

// Legacy alias used across the codebase
typealias Card = PlayingCard

enum CardColor: String, Codable, CaseIterable, Hashable {
    case red, blue, green, yellow, wild
    var displayName: String { rawValue.capitalized }
}

enum CardValue: String, Codable, Hashable {
    case zero, one, two, three, four, five, six, seven, eight, nine
    case skip, reverse, drawTwo, wild, wildDrawFour
}
