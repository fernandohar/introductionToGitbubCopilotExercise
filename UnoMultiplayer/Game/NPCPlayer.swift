import Foundation

struct NPCPlayer {
    static func chooseMove(
        for player: Player,
        in state: GameState,
        variant: UnoVariant,
        difficulty: NPCDifficulty
    ) -> (card: Card, color: CardColor?)? {
        let playable = UnoEngine.playableCards(in: player.hand, for: state, variant: variant)
        guard !playable.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            let card = playable.randomElement()!
            return (card, randomColorIfNeeded(for: card))

        case .medium:
            if let action = playable.first(where: { !$0.value.isNumber }) {
                return (action, randomColorIfNeeded(for: action))
            }
            return (playable.first!, randomColorIfNeeded(for: playable.first!))

        case .hard:
            if state.pendingDrawCount > 0,
               let stack = playable.first(where: { $0.value == .wildDrawFour || $0.value == .drawTwo }) {
                return (stack, randomColorIfNeeded(for: stack))
            }

            let opponents = state.players.filter { $0.id != player.id }
            if let vulnerable = opponents.first(where: { $0.cardCount <= 2 }),
               let attack = playable.first(where: { $0.value == .wildDrawFour || $0.value == .drawTwo || $0.value == .skip }) {
                return (attack, bestColor(for: player, avoiding: vulnerable))
            }

            if let wild = playable.first(where: { $0.isWild }) {
                return (wild, dominantColor(in: player.hand))
            }

            return (playable.first!, randomColorIfNeeded(for: playable.first!))
        }
    }

    private static func randomColorIfNeeded(for card: Card) -> CardColor? {
        card.isWild ? CardColor.allCases.filter { $0 != .wild }.randomElement() : nil
    }

    private static func dominantColor(in hand: [Card]) -> CardColor {
        let colors = hand.filter { !$0.isWild }.map(\.color)
        let counts = Dictionary(grouping: colors, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .red
    }

    private static func bestColor(for player: Player, avoiding opponent: Player) -> CardColor? {
        let opponentColors = Set(opponent.hand.filter { !$0.isWild }.map(\.color))
        let preferred = dominantColor(in: player.hand)
        return opponentColors.contains(preferred)
            ? CardColor.allCases.filter { $0 != .wild && !opponentColors.contains($0) }.first
            : preferred
    }
}
