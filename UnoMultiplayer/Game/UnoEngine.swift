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
    static let startingHandSize = 7
    static let minPlayers = 2
    static let maxPlayers = 10

    static func startGame(players: [Player]) throws -> GameState {
        guard players.count >= minPlayers else {
            throw UnoEngineError.notEnoughPlayers
        }

        var deck = Deck()
        var mutablePlayers = players

        for index in mutablePlayers.indices {
            mutablePlayers[index].hand = (0 ..< startingHandSize).compactMap { _ in deck.draw() }
        }

        var discardPile: [Card] = []
        var activeColor: CardColor?

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

        return GameState(
            phase: .inProgress,
            players: mutablePlayers,
            currentPlayerIndex: 0,
            direction: .clockwise,
            drawPile: deck.cards,
            discardPile: discardPile,
            activeColor: activeColor
        )
    }

    static func playableCards(in hand: [Card], for state: GameState) -> [Card] {
        guard let topCard = state.topCard else { return hand }
        return hand.filter { card in
            if state.pendingDrawCount > 0 {
                return card.value == .drawTwo || card.value == .wildDrawFour
            }
            return card.matches(topCard: topCard, activeColor: state.activeColor)
        }
    }

    static func canPlay(card: Card, from playerID: UUID, in state: GameState) -> Bool {
        guard state.phase == .inProgress,
              state.currentPlayer?.id == playerID,
              let topCard = state.topCard else { return false }

        if card.isWild && card.value == .wildDrawFour {
            let hasPlayableNonWild = state.currentPlayer?.hand.contains { handCard in
                !handCard.isWild && handCard.matches(topCard: topCard, activeColor: state.activeColor)
            } ?? false
            if hasPlayableNonWild { return false }
        }

        if state.pendingDrawCount > 0 {
            return card.value == .drawTwo || card.value == .wildDrawFour
        }

        return card.matches(topCard: topCard, activeColor: state.activeColor)
    }

    static func play(
        card: Card,
        chosenColor: CardColor? = nil,
        from playerID: UUID,
        in state: inout GameState
    ) throws {
        guard state.phase == .inProgress else { throw UnoEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw UnoEngineError.notPlayersTurn }
        guard canPlay(card: card, from: playerID, in: state) else { throw UnoEngineError.invalidCard }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }),
              let cardIndex = state.players[playerIndex].hand.firstIndex(of: card) else {
            throw UnoEngineError.invalidCard
        }

        if card.isWild {
            guard let chosenColor, chosenColor != .wild else { throw UnoEngineError.mustChooseColor }
            state.activeColor = chosenColor
        } else {
            state.activeColor = card.color
        }

        state.players[playerIndex].hand.remove(at: cardIndex)
        state.discardPile.append(card)

        if state.players[playerIndex].hasWon {
            state.phase = .finished
            state.winnerID = playerID
            return
        }

        applyCardEffect(card, in: &state)
        advanceTurn(in: &state)
    }

    static func drawCard(for playerID: UUID, in state: inout GameState) throws -> Card? {
        guard state.phase == .inProgress else { throw UnoEngineError.gameNotInProgress }
        guard state.currentPlayer?.id == playerID else { throw UnoEngineError.notPlayersTurn }

        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw UnoEngineError.invalidCard
        }

        refillDrawPileIfNeeded(in: &state)
        guard let drawnCard = state.drawPile.first else { return nil }
        state.drawPile.removeFirst()
        state.players[playerIndex].hand.append(drawnCard)

        if state.pendingDrawCount > 0 {
            state.pendingDrawCount = max(0, state.pendingDrawCount - 1)
            if state.pendingDrawCount == 0 {
                advanceTurn(in: &state)
            }
        }

        return drawnCard
    }

    static func drawPendingCards(for playerID: UUID, in state: inout GameState) throws {
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
        advanceTurn(in: &state)
    }

    private static func applyCardEffect(_ card: Card, in state: inout GameState) {
        switch card.value {
        case .skip:
            advanceTurn(in: &state)
        case .reverse:
            state.direction = state.direction == .clockwise ? .counterClockwise : .clockwise
            if state.players.count == 2 {
                advanceTurn(in: &state)
            }
        case .drawTwo:
            state.pendingDrawCount += 2
        case .wildDrawFour:
            state.pendingDrawCount += 4
        default:
            break
        }
    }

    private static func advanceTurn(in state: inout GameState) {
        guard !state.players.isEmpty else { return }
        let delta = state.direction.rawValue
        state.currentPlayerIndex = (state.currentPlayerIndex + delta + state.players.count) % state.players.count
    }

    private static func refillDrawPileIfNeeded(in state: inout GameState) {
        guard state.drawPile.isEmpty, state.discardPile.count > 1 else { return }
        let topCard = state.discardPile.removeLast()
        state.drawPile = state.discardPile.shuffled()
        state.discardPile = [topCard]
    }
}
