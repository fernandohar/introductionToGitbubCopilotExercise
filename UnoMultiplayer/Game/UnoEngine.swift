import Foundation

enum UnoEngineError: LocalizedError, Equatable {
    case notEnoughPlayers
    case notPlayersTurn
    case invalidCard
    case mustChooseColor
    case gameNotInProgress

    var errorDescription: String? {
        switch self {
        case .notEnoughPlayers: return "At least 2 players are required to start."
        case .notPlayersTurn: return "It is not your turn."
        case .invalidCard: return "That card cannot be played."
        case .mustChooseColor: return "Choose a color for the wild card."
        case .gameNotInProgress: return "The game is not in progress."
        }
    }
}

struct UnoEngine {
    static let minPlayers = 2
    static let maxPlayers = 10

    static func startGame(players: [Player], variant: UnoVariant) throws -> GameState {
        guard players.count >= minPlayers else {
            throw UnoEngineError.notEnoughPlayers
        }

        var deck = Deck(configuration: variant.deck)
        var mutablePlayers = players

        for index in mutablePlayers.indices {
            mutablePlayers[index].hand = (0 ..< variant.deck.startingHandSize).compactMap { _ in deck.draw() }
            mutablePlayers[index].isReady = false
        }

        var discardPile: [Card] = []
        var activeColor: CardColor?

        if variant.deck.allWild {
            if let card = deck.draw() {
                discardPile.append(card)
                activeColor = CardColor.allCases.filter { $0 != .wild }.randomElement()
            }
        } else {
            while let card = deck.draw() {
                if card.isWild {
                    deck.cards.append(card)
                    deck.cards.shuffle()
                    continue
                }
                discardPile.append(card)
                activeColor = card.color
                break
            }
        }

        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            currentPlayerIndex: 0,
            direction: .clockwise,
            drawPile: deck.cards,
            discardPile: discardPile,
            activeColor: activeColor,
            variantID: variant.id,
            turnDeadline: Date().addingTimeInterval(TimeInterval(variant.deck.turnTimeLimit))
        )
    }

    static func playableCards(in hand: [Card], for state: GameState, variant: UnoVariant) -> [Card] {
        if variant.deck.allWild {
            return hand
        }
        guard let topCard = state.topCard else { return hand }
        return hand.filter { card in
            if state.pendingDrawCount > 0 {
                if variant.deck.allowStackingDraws {
                    return card.value == .drawTwo || card.value == .wildDrawFour
                }
                return false
            }
            return card.matches(topCard: topCard, activeColor: state.activeColor)
        }
    }

    static func canPlay(card: Card, from playerID: UUID, in state: GameState, variant: UnoVariant) -> Bool {
        guard state.phase == .inProgress,
              state.currentPlayer?.id == playerID else { return false }

        if variant.deck.allWild { return true }

        guard let topCard = state.topCard else { return false }

        if card.isWild && card.value == .wildDrawFour && !variant.deck.allowStackingDraws {
            let hasPlayableNonWild = state.currentPlayer?.hand.contains { handCard in
                !handCard.isWild && handCard.matches(topCard: topCard, activeColor: state.activeColor)
            } ?? false
            if hasPlayableNonWild { return false }
        }

        if state.pendingDrawCount > 0 {
            if variant.deck.allowStackingDraws {
                return card.value == .drawTwo || card.value == .wildDrawFour
            }
            return false
        }

        return card.matches(topCard: topCard, activeColor: state.activeColor)
    }

    static func play(
        card: Card,
        chosenColor: CardColor? = nil,
        from playerID: UUID,
        in state: inout GameState,
        variant: UnoVariant
    ) throws {
        guard state.phase == .inProgress else { throw UnoEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw UnoEngineError.notPlayersTurn }
        guard canPlay(card: card, from: playerID, in: state, variant: variant) else {
            throw UnoEngineError.invalidCard
        }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              let cardIndex = state.players[playerIndex].hand.firstIndex(of: card) else {
            throw UnoEngineError.invalidCard
        }

        if card.isWild || variant.deck.allWild {
            let color = chosenColor ?? CardColor.allCases.filter { $0 != .wild }.randomElement()
            guard let color, color != .wild else { throw UnoEngineError.mustChooseColor }
            state.activeColor = color
        } else {
            state.activeColor = card.color
        }

        state.players[playerIndex].hand.remove(at: cardIndex)
        state.discardPile.append(card)

        if state.players[playerIndex].hasWon {
            state.phase = .finished
            state.winnerID = playerID
            state.turnDeadline = nil
            return
        }

        applyCardEffect(card, in: &state, variant: variant)
        resetTurnDeadline(in: &state, variant: variant)
    }

    static func drawCard(for playerID: UUID, in state: inout GameState, variant: UnoVariant) throws -> Card? {
        guard state.phase == .inProgress else { throw UnoEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw UnoEngineError.notPlayersTurn }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw UnoEngineError.invalidCard
        }

        refillDrawPileIfNeeded(in: &state)
        guard let drawnCard = state.drawPile.first else { return nil }
        state.drawPile.removeFirst()
        state.players[playerIndex].hand.append(drawnCard)

        if state.pendingDrawCount > 0 && !variant.deck.allowStackingDraws {
            try drawPendingCards(for: playerID, in: &state, variant: variant)
        } else {
            advanceTurn(in: &state, variant: variant)
            resetTurnDeadline(in: &state, variant: variant)
        }

        return drawnCard
    }

    static func drawPendingCards(for playerID: UUID, in state: inout GameState, variant: UnoVariant) throws {
        guard state.pendingDrawCount > 0 else { return }
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else { return }

        for _ in 0 ..< state.pendingDrawCount {
            refillDrawPileIfNeeded(in: &state)
            if let card = state.drawPile.first {
                state.drawPile.removeFirst()
                state.players[playerIndex].hand.append(card)
            }
        }

        state.pendingDrawCount = 0
        advanceTurn(in: &state, variant: variant)
        resetTurnDeadline(in: &state, variant: variant)
    }

    static func handleTurnTimeout(for playerID: UUID, in state: inout GameState, variant: UnoVariant) throws {
        guard state.currentPlayer?.id == playerID else { return }
        if state.pendingDrawCount > 0 {
            try drawPendingCards(for: playerID, in: &state, variant: variant)
        } else {
            _ = try drawCard(for: playerID, in: &state, variant: variant)
        }
    }

    static func resetTurnDeadline(in state: inout GameState, variant: UnoVariant) {
        state.turnDeadline = Date().addingTimeInterval(TimeInterval(variant.deck.turnTimeLimit))
    }

    private static func applyCardEffect(_ card: Card, in state: inout GameState, variant: UnoVariant) {
        switch card.value {
        case .skip:
            advanceTurn(in: &state, variant: variant)
        case .reverse:
            state.direction = state.direction == .clockwise ? .counterClockwise : .clockwise
            if state.players.count == 2 {
                advanceTurn(in: &state, variant: variant)
            }
        case .drawTwo:
            state.pendingDrawCount += 2
        case .wildDrawFour:
            state.pendingDrawCount += 4
        default:
            advanceTurn(in: &state, variant: variant)
        }
    }

    private static func advanceTurn(in state: inout GameState, variant: UnoVariant) {
        guard !state.players.isEmpty else { return }
        let delta = state.direction.rawValue
        state.currentPlayerIndex = (state.currentPlayerIndex + delta + state.players.count) % state.players.count
        resetTurnDeadline(in: &state, variant: variant)
    }

    private static func refillDrawPileIfNeeded(in state: inout GameState) {
        guard state.drawPile.isEmpty, state.discardPile.count > 1 else { return }
        let topCard = state.discardPile.removeLast()
        state.drawPile = state.discardPile.shuffled()
        state.discardPile = [topCard]
    }
}
