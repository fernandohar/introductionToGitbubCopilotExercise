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
            return value < 12
        }
    }
}
