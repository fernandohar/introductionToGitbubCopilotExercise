import Foundation

struct BigTwoEngine {
    static func startGame(players: [Player], variant: GameVariant) throws -> GameState {
        guard players.count >= variant.settings.minPlayers else {
            throw GameEngineError.notEnoughPlayers
        }

        var deck = StandardDeck()
        var mutablePlayers = players
        let cardsEach = 52 / mutablePlayers.count

        for index in mutablePlayers.indices {
            mutablePlayers[index].hand = (0 ..< cardsEach).compactMap { _ in deck.draw() }
            mutablePlayers[index].isReady = false
        }

        let starterIndex = mutablePlayers.firstIndex {
            $0.hand.contains(where: \.isThreeOfDiamonds)
        } ?? 0

        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            currentPlayerIndex: starterIndex,
            drawPile: deck.cards,
            engineType: .bigTwo,
            gameID: variant.id,
            turnDeadline: Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit)),
            tableLabel: "Play 3♦ to start"
        )
    }

    static func playableCards(in hand: [PlayingCard], for state: GameState) -> [PlayingCard] {
        guard let top = state.topCard else {
            if state.isTableOpen { return hand }
            return hand.filter(\.isThreeOfDiamonds)
        }
        return hand.filter { $0.beats(top) }
    }

    static func play(
        card: PlayingCard,
        from playerID: UUID,
        in state: inout GameState,
        variant: GameVariant
    ) throws {
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              let cardIndex = state.players[playerIndex].hand.firstIndex(of: card) else {
            throw GameEngineError.invalidCard
        }

        let playable = playableCards(in: state.players[playerIndex].hand, for: state)
        guard playable.contains(card) else { throw GameEngineError.invalidCard }

        state.players[playerIndex].hand.remove(at: cardIndex)
        state.tableCards = [card]
        state.tableLabel = "\(card.rank.displayName)\(card.suit.symbol)"
        state.passesInRow = 0
        state.isTableOpen = false

        if state.players[playerIndex].hasWon {
            state.phase = .finished
            state.winnerID = playerID
            state.turnDeadline = nil
            return
        }

        advanceTurn(in: &state, variant: variant)
    }

    static func pass(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }
        guard state.topCard != nil else { throw GameEngineError.invalidCard }

        let hand = state.players.first { $0.id == playerID }?.hand ?? []
        guard playableCards(in: hand, for: state).isEmpty else { throw GameEngineError.invalidCard }

        state.passesInRow += 1

        if state.passesInRow >= state.players.count - 1 {
            state.tableCards = []
            state.isTableOpen = true
            state.tableLabel = "Table cleared — play any card"
            state.passesInRow = 0
        }

        advanceTurn(in: &state, variant: variant)
    }

    private static func advanceTurn(in state: inout GameState, variant: GameVariant) {
        let delta = state.direction.rawValue
        state.currentPlayerIndex = (state.currentPlayerIndex + delta + state.players.count) % state.players.count
        GameEngineRouter.resetTurnDeadline(in: &state, variant: variant)
    }
}
