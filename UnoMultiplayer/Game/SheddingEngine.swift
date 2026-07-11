import Foundation

struct SheddingEngine {
    static func startGame(players: [Player], variant: GameVariant) throws -> GameState {
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        guard players.count >= variant.settings.minPlayers else {
            throw GameEngineError.notEnoughPlayers
        }

        var deck = SheddingDeck(config: config)
        var mutablePlayers = players

        for index in mutablePlayers.indices {
            mutablePlayers[index].sheddingHand = (0 ..< config.startingHandSize).compactMap { _ in deck.draw() }
            mutablePlayers[index].isReady = false
        }

        var table: [SheddingCard] = []
        var activeColor: SheddingColor?

        while let card = deck.draw() {
            if card.isWild {
                deck.cards.append(card)
                deck.cards.shuffle()
                continue
            }
            table.append(card)
            activeColor = card.color
            break
        }

        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            sheddingDrawPile: deck.cards,
            sheddingTable: table,
            activeSheddingColor: activeColor,
            gameID: variant.id,
            engineType: .shedding,
            turnDeadline: Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit)),
            tableLabel: "Match colour or number"
        )
    }

    static func playableCards(in hand: [SheddingCard], for state: GameState, config: SheddingDeckConfig) -> [SheddingCard] {
        guard let top = state.topSheddingCard else { return hand }
        return hand.filter { card in
            if state.pendingDrawCount > 0 {
                return config.allowStackingDraws && (card.value == .drawTwo || card.value == .wildDrawFour)
            }
            return card.matches(topCard: top, activeColor: state.activeSheddingColor)
        }
    }

    static func play(
        card: SheddingCard,
        chosenColor: SheddingColor? = nil,
        from playerID: UUID,
        in state: inout GameState,
        variant: GameVariant
    ) throws {
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }
        guard playableCards(in: state.players.first { $0.id == playerID }?.sheddingHand ?? [], for: state, config: config).contains(card) else {
            throw GameEngineError.invalidCard
        }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              let cardIndex = state.players[playerIndex].sheddingHand.firstIndex(of: card) else {
            throw GameEngineError.invalidCard
        }

        if card.isWild {
            guard let chosenColor, chosenColor != .wild else { throw GameEngineError.invalidCard }
            state.activeSheddingColor = chosenColor
        } else {
            state.activeSheddingColor = card.color
        }

        state.players[playerIndex].sheddingHand.remove(at: cardIndex)
        state.sheddingTable = [card]
        state.tableLabel = "\(card.color.displayName) \(card.value.displayName)"

        if state.players[playerIndex].hasWon {
            state.phase = .finished
            state.winnerID = playerID
            state.turnDeadline = nil
            return
        }

        applyEffect(card, in: &state, variant: variant)
        if card.value != .drawTwo && card.value != .wildDrawFour {
            advanceTurn(in: &state, variant: variant)
        }
    }

    static func drawCard(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else { return }

        refillDrawPile(in: &state)
        guard let drawn = state.sheddingDrawPile.first else { return }
        state.sheddingDrawPile.removeFirst()
        state.players[playerIndex].sheddingHand.append(drawn)

        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        if state.pendingDrawCount > 0 && !config.allowStackingDraws {
            try drawPending(for: playerID, in: &state, variant: variant)
        } else {
            advanceTurn(in: &state, variant: variant)
        }
    }

    static func drawPending(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        guard state.pendingDrawCount > 0,
              let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else { return }

        for _ in 0 ..< state.pendingDrawCount {
            refillDrawPile(in: &state)
            if let card = state.sheddingDrawPile.first {
                state.sheddingDrawPile.removeFirst()
                state.players[playerIndex].sheddingHand.append(card)
            }
        }
        state.pendingDrawCount = 0
        advanceTurn(in: &state, variant: variant)
    }

    static func handleTurnTimeout(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        let hand = state.players.first { $0.id == playerID }?.sheddingHand ?? []
        if state.pendingDrawCount > 0 {
            try drawPending(for: playerID, in: &state, variant: variant)
        } else if let card = playableCards(in: hand, for: state, config: config).first {
            try play(card: card, chosenColor: card.isWild ? .red : nil, from: playerID, in: &state, variant: variant)
        } else {
            try drawCard(for: playerID, in: &state, variant: variant)
        }
    }

    private static func applyEffect(_ card: SheddingCard, in state: inout GameState, variant: GameVariant) {
        switch card.value {
        case .skip: advanceTurn(in: &state, variant: variant)
        case .reverse:
            state.direction = state.direction == .clockwise ? .counterClockwise : .clockwise
            if state.players.count == 2 { advanceTurn(in: &state, variant: variant) }
        case .drawTwo: state.pendingDrawCount += 2
        case .wildDrawFour: state.pendingDrawCount += 4
        default: break
        }
    }

    private static func advanceTurn(in state: inout GameState, variant: GameVariant) {
        let delta = state.direction.rawValue
        state.currentPlayerIndex = (state.currentPlayerIndex + delta + state.players.count) % state.players.count
        GameEngineRouter.resetTurnDeadline(in: &state, variant: variant)
    }

    private static func refillDrawPile(in state: inout GameState) {
        guard state.sheddingDrawPile.isEmpty, state.sheddingTable.count > 1 else { return }
        let top = state.sheddingTable.removeLast()
        state.sheddingDrawPile = state.sheddingTable.shuffled()
        state.sheddingTable = [top]
    }
}
