import Foundation

struct Deck {
    private(set) var cards: [Card] = []

    init(configuration: DeckConfiguration, shuffled: Bool = true) {
        cards = Self.buildCards(configuration: configuration)
        if shuffled {
            cards.shuffle()
        }
    }

    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    private static func buildCards(configuration: DeckConfiguration) -> [Card] {
        if configuration.allWild {
            var cards: [Card] = []
            let wildValues: [CardValue] = [.wild, .wildDrawFour, .skip, .reverse, .drawTwo]
            for value in wildValues {
                for _ in 0 ..< 8 {
                    cards.append(Card(color: .wild, value: value))
                }
            }
            return cards
        }

        var cards: [Card] = []
        let colors: [CardColor] = [.red, .blue, .green, .yellow]
        let numbers: [CardValue] = [.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine]

        for color in colors {
            for number in numbers {
                let count = number == .zero ? 1 : 2
                for _ in 0 ..< count {
                    cards.append(Card(color: color, value: number))
                }
            }

            if configuration.includeSkip {
                for _ in 0 ..< 2 { cards.append(Card(color: color, value: .skip)) }
            }
            if configuration.includeReverse {
                for _ in 0 ..< 2 { cards.append(Card(color: color, value: .reverse)) }
            }
            if configuration.includeDrawTwo {
                for _ in 0 ..< 2 { cards.append(Card(color: color, value: .drawTwo)) }
            }
        }

        if configuration.includeWild {
            for _ in 0 ..< 4 { cards.append(Card(color: .wild, value: .wild)) }
        }
        if configuration.includeWildDrawFour {
            for _ in 0 ..< 4 { cards.append(Card(color: .wild, value: .wildDrawFour)) }
        }

        return cards
    }
}
