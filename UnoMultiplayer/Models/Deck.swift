import Foundation

struct Deck {
    private(set) var cards: [Card] = []

    init(shuffled: Bool = true) {
        cards = Self.standardCards()
        if shuffled {
            cards.shuffle()
        }
    }

    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    private static func standardCards() -> [Card] {
        var cards: [Card] = []
        let colors: [CardColor] = [.red, .blue, .green, .yellow]
        let numbers: [CardValue] = [.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        let actions: [CardValue] = [.skip, .reverse, .drawTwo]

        for color in colors {
            for number in numbers {
                let count = number == .zero ? 1 : 2
                for _ in 0 ..< count {
                    cards.append(Card(color: color, value: number))
                }
            }
            for action in actions {
                for _ in 0 ..< 2 {
                    cards.append(Card(color: color, value: action))
                }
            }
        }

        for _ in 0 ..< 4 {
            cards.append(Card(color: .wild, value: .wild))
            cards.append(Card(color: .wild, value: .wildDrawFour))
        }

        return cards
    }
}
