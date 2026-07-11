import Foundation

struct BlackjackEngine {
    static func startGame(players: [Player], variant: GameVariant) throws -> GameState {
        guard !players.isEmpty else { throw GameEngineError.notEnoughPlayers }

        var deck = StandardDeck()
        var mutablePlayers = players

        for index in mutablePlayers.indices where !mutablePlayers[index].isNPC {
            mutablePlayers[index].hand = [deck.draw(), deck.draw()].compactMap { $0 }
            mutablePlayers[index].isReady = false
        }

        var dealerHand: [PlayingCard] = [deck.draw(), deck.draw()].compactMap { $0 }

        let humanIndex = mutablePlayers.firstIndex { !$0.isNPC } ?? 0

        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            currentPlayerIndex: humanIndex,
            drawPile: deck.cards,
            dealerHand: dealerHand,
            engineType: .blackjack,
            gameID: variant.id,
            turnDeadline: Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit)),
            tableLabel: "Beat the dealer — don't go over 21",
            blackjackStatus: "Your turn — Hit or Stand"
        )
    }

    static func hit(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else { return }
        guard let card = state.drawPile.first else { return }

        state.drawPile.removeFirst()
        state.players[playerIndex].hand.append(card)

        let value = handValue(state.players[playerIndex].hand)
        if value > 21 {
            state.phase = .finished
            state.blackjackStatus = "Bust! You went over 21."
            state.turnDeadline = nil
        } else if value == 21 {
            try stand(from: playerID, in: &state, variant: variant)
        } else {
            state.blackjackStatus = "Hand: \(value) — Hit or Stand"
            GameEngineRouter.resetTurnDeadline(in: &state, variant: variant)
        }
    }

    static func stand(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else { return }
        let playerValue = handValue(state.players[playerIndex].hand)

        while handValue(state.dealerHand) < 17, let card = state.drawPile.first {
            state.drawPile.removeFirst()
            state.dealerHand.append(card)
        }

        let dealerValue = handValue(state.dealerHand)
        state.phase = .finished
        state.turnDeadline = nil

        if dealerValue > 21 {
            state.winnerID = playerID
            state.blackjackStatus = "Dealer busts! You win with \(playerValue)."
        } else if playerValue > dealerValue {
            state.winnerID = playerID
            state.blackjackStatus = "You win! \(playerValue) vs dealer \(dealerValue)."
        } else if playerValue < dealerValue {
            state.blackjackStatus = "Dealer wins. \(dealerValue) vs your \(playerValue)."
        } else {
            state.blackjackStatus = "Push — it's a tie at \(playerValue)."
        }
    }

    static func handValue(_ hand: [PlayingCard]) -> Int {
        var total = hand.reduce(0) { $0 + $1.rank.blackjackValue }
        var aces = hand.filter { $0.rank == .ace }.count

        while total > 21, aces > 0 {
            total -= 10
            aces -= 1
        }
        return total
    }
}
