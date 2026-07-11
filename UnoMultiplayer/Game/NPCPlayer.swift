import Foundation

struct NPCPlayer {
    static func chooseBigTwoMove(
        for player: Player,
        in state: GameState,
        difficulty: NPCDifficulty
    ) -> (card: PlayingCard?, shouldPass: Bool) {
        let playable = BigTwoEngine.playableCards(in: player.hand, for: state)
        guard !playable.isEmpty else { return (nil, true) }

        switch difficulty {
        case .easy:
            return (playable.randomElement(), false)
        case .medium:
            return (playable.min(by: { $0.bigTwoPower < $1.bigTwoPower }), false)
        case .hard:
            return (playable.max(by: { $0.bigTwoPower < $1.bigTwoPower }), false)
        }
    }

    static func chooseBlackjackAction(
        for player: Player,
        in state: GameState,
        difficulty: NPCDifficulty
    ) -> Bool {
        let value = BlackjackEngine.handValue(player.hand)
        switch difficulty {
        case .easy: return value < 12
        case .medium: return value < 17
        case .hard:
            let dealerUpcard = state.dealerHand.first?.rank.blackjackValue ?? 10
            if value >= 17 { return false }
            if dealerUpcard >= 7 && value < 17 { return true }
    static func chooseSheddingMove(
        for player: Player,
        in state: GameState,
        variant: GameVariant,
        difficulty: NPCDifficulty
    ) -> (card: SheddingCard?, color: SheddingColor?) {
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        let playable = SheddingEngine.playableCards(in: player.sheddingHand, for: state, config: config)
        guard !playable.isEmpty else { return (nil, nil) }

        switch difficulty {
        case .easy:
            let card = playable.randomElement()!
            return (card, card.isWild ? SheddingColor.allCases.filter { $0 != .wild }.randomElement() : nil)
        case .medium:
            if let action = playable.first(where: { !$0.value.isNumber }) {
                return (action, action.isWild ? .red : nil)
            }
            let card = playable.first!
            return (card, card.isWild ? .red : nil)
        case .hard:
            if state.pendingDrawCount > 0,
               let stack = playable.first(where: { $0.value == .wildDrawFour || $0.value == .drawTwo }) {
                return (stack, stack.isWild ? .red : nil)
            }
            if let wild = playable.first(where: { $0.isWild }) {
                return (wild, dominantSheddingColor(in: player.sheddingHand))
            }
            let card = playable.first!
            return (card, nil)
        }
    }

    private static func dominantSheddingColor(in hand: [SheddingCard]) -> SheddingColor {
        let colors = hand.filter { !$0.isWild }.map(\.color)
        let counts = Dictionary(grouping: colors, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .red
    }
}
