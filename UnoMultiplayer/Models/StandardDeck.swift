import Foundation

struct StandardDeck {
    private(set) var cards: [PlayingCard] = []

    init(shuffled: Bool = true) {
        cards = CardSuit.allCases.flatMap { suit in
            PlayingRank.allCases.map { rank in
                PlayingCard(suit: suit, rank: rank)
            }
        }
        if shuffled { cards.shuffle() }
    }

    mutating func draw() -> PlayingCard? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }
}
