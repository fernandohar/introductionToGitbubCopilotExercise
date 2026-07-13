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
            mutablePlayers[index].isEliminated = false
            mutablePlayers[index].hasCalledOneLeft = false
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

        let rules = variant.resolvedSheddingRules
        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            currentPlayerIndex: firstActivePlayerIndex(in: mutablePlayers),
            sheddingDrawPile: deck.cards,
            sheddingTable: table,
            activeSheddingColor: activeColor,
            gameID: variant.id,
            engineType: .shedding,
            turnDeadline: Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit)),
            tableLabel: tableLabel(for: rules)
        )
    }

    static func playableCards(in hand: [SheddingCard], for state: GameState, variant: GameVariant) -> [SheddingCard] {
        let rules = variant.resolvedSheddingRules
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        guard let top = state.topSheddingCard else { return hand }
        return hand.filter { card in
            if state.pendingDrawCount > 0 {
                return rules.allowStackingDraws && (card.value == .drawTwo || card.value == .wildDrawFour)
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
        let rules = variant.resolvedSheddingRules
        let config = variant.sheddingDeck ?? SheddingDeckConfig()
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              !state.players[playerIndex].isEliminated else { throw GameEngineError.notPlayersTurn }
        guard playableCards(in: state.players[playerIndex].sheddingHand, for: state, variant: variant).contains(card) else {
            throw GameEngineError.invalidCard
        }

        guard let cardIndex = state.players[playerIndex].sheddingHand.firstIndex(of: card) else {
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

        syncOneLeftCallState(for: playerIndex, in: &state)

        if checkWinOrEliminationVictory(in: &state, rules: rules) { return }

        applyEffect(card, in: &state, variant: variant)
        if card.value != .drawTwo && card.value != .wildDrawFour {
            advanceTurn(in: &state, variant: variant)
        }
    }

    static func drawCard(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        let rules = variant.resolvedSheddingRules
        guard state.phase == .inProgress else { throw GameEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw GameEngineError.notPlayersTurn }
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              !state.players[playerIndex].isEliminated else { return }

        refillDrawPile(in: &state)
        guard let drawn = state.sheddingDrawPile.first else { return }
        state.sheddingDrawPile.removeFirst()
        state.players[playerIndex].sheddingHand.append(drawn)
        syncOneLeftCallState(for: playerIndex, in: &state)

        if eliminateIfNeeded(playerIndex: playerIndex, in: &state, rules: rules) {
            if checkWinOrEliminationVictory(in: &state, rules: rules) { return }
            advanceTurn(in: &state, variant: variant)
            return
        }

        if state.pendingDrawCount > 0 && !rules.allowStackingDraws {
            try drawPending(for: playerID, in: &state, variant: variant)
        } else {
            advanceTurn(in: &state, variant: variant)
        }
    }

    static func drawPending(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        let rules = variant.resolvedSheddingRules
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
        syncOneLeftCallState(for: playerIndex, in: &state)
        eliminateIfNeeded(playerIndex: playerIndex, in: &state, rules: rules)
        if !checkWinOrEliminationVictory(in: &state, rules: rules) {
            advanceTurn(in: &state, variant: variant)
        }
    }

    static func callOneLeft(for playerID: UUID, in state: inout GameState) {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }),
              state.players[index].sheddingHand.count == 1 else { return }
        state.players[index].hasCalledOneLeft = true
        state.tableLabel = "\(state.players[index].displayName) — one left!"
    }

    static func handleTurnTimeout(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        let rules = variant.resolvedSheddingRules
        let hand = state.players.first { $0.id == playerID }?.sheddingHand ?? []
        if state.pendingDrawCount > 0 {
            try drawPending(for: playerID, in: &state, variant: variant)
        } else if let card = playableCards(in: hand, for: state, variant: variant).first {
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
            if activePlayerCount(in: state) == 2 { advanceTurn(in: &state, variant: variant) }
        case .drawTwo: state.pendingDrawCount += 2
        case .wildDrawFour: state.pendingDrawCount += 4
        default: break
        }
    }

    private static func advanceTurn(in state: inout GameState, variant: GameVariant) {
        let rules = variant.resolvedSheddingRules
        applyOneLeftPenaltyBeforeLeavingTurn(in: &state, rules: rules)

        guard activePlayerCount(in: state) > 0 else { return }
        let delta = state.direction.rawValue
        var next = state.currentPlayerIndex
        repeat {
            next = (next + delta + state.players.count) % state.players.count
        } while state.players[next].isEliminated

        state.currentPlayerIndex = next
        GameEngineRouter.resetTurnDeadline(in: &state, variant: variant)
    }

    private static func applyOneLeftPenaltyBeforeLeavingTurn(in state: inout GameState, rules: SheddingRules) {
        guard rules.requireOneLeftCall else { return }
        let index = state.currentPlayerIndex
        guard state.players[index].sheddingHand.count == 1,
              !state.players[index].hasCalledOneLeft else { return }

        for _ in 0 ..< rules.oneLeftPenaltyCards {
            refillDrawPile(in: &state)
            if let card = state.sheddingDrawPile.first {
                state.sheddingDrawPile.removeFirst()
                state.players[index].sheddingHand.append(card)
            }
        }
        state.tableLabel = "\(state.players[index].displayName) forgot — +\(rules.oneLeftPenaltyCards)"
        eliminateIfNeeded(playerIndex: index, in: &state, rules: rules)
    }

    @discardableResult
    private static func eliminateIfNeeded(playerIndex: Int, in state: inout GameState, rules: SheddingRules) -> Bool {
        guard let limit = rules.maxHandBeforeElimination else { return false }
        guard state.players[playerIndex].sheddingHand.count > limit else { return false }
        state.players[playerIndex].isEliminated = true
        state.players[playerIndex].sheddingHand = []
        state.tableLabel = "\(state.players[playerIndex].displayName) eliminated — over \(limit) cards"
        return true
    }

    @discardableResult
    private static func checkWinOrEliminationVictory(in state: inout GameState, rules: SheddingRules) -> Bool {
        if let winner = state.players.first(where: { $0.hasWon }) {
            state.phase = .finished
            state.winnerID = winner.id
            state.turnDeadline = nil
            return true
        }

        let active = state.players.filter(\.isActiveInSheddingGame)
        if active.count == 1 {
            state.phase = .finished
            state.winnerID = active[0].id
            state.turnDeadline = nil
            state.tableLabel = "\(active[0].displayName) wins — last player standing"
            return true
        }
        return false
    }

    private static func syncOneLeftCallState(for playerIndex: Int, in state: inout GameState) {
        if state.players[playerIndex].sheddingHand.count != 1 {
            state.players[playerIndex].hasCalledOneLeft = false
        }
    }

    private static func activePlayerCount(in state: GameState) -> Int {
        state.players.filter(\.isActiveInSheddingGame).count
    }

    private static func firstActivePlayerIndex(in players: [Player]) -> Int {
        players.firstIndex(where: \.isActiveInSheddingGame) ?? 0
    }

    private static func tableLabel(for rules: SheddingRules) -> String {
        switch rules.profile {
        case "showNoMercy": "Show No Mercy — match or draw"
        case "golf": "Fairway Match — match colour or number"
        default: "Match colour or number"
        }
    }

    private static func refillDrawPile(in state: inout GameState) {
        guard state.sheddingDrawPile.isEmpty, state.sheddingTable.count > 1 else { return }
        let top = state.sheddingTable.removeLast()
        state.sheddingDrawPile = state.sheddingTable.shuffled()
        state.sheddingTable = [top]
    }
}
