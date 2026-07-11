import Foundation

enum GamePhase: String, Codable {
    case lobby
    case inProgress
    case finished
}

enum TurnDirection: Int, Codable {
    case clockwise = 1
    case counterClockwise = -1
}

struct GameState: Codable {
    var phase: GamePhase
    var players: [Player]
    var currentPlayerIndex: Int
    var direction: TurnDirection
    var drawPile: [Card]
    var discardPile: [Card]
    var activeColor: CardColor?
    var pendingDrawCount: Int
    var winnerID: UUID?

    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    var topCard: Card? {
        discardPile.last
    }

    init(
        phase: GamePhase = .lobby,
        players: [Player] = [],
        currentPlayerIndex: Int = 0,
        direction: TurnDirection = .clockwise,
        drawPile: [Card] = [],
        discardPile: [Card] = [],
        activeColor: CardColor? = nil,
        pendingDrawCount: Int = 0,
        winnerID: UUID? = nil
    ) {
        self.phase = phase
        self.players = players
        self.currentPlayerIndex = currentPlayerIndex
        self.direction = direction
        self.drawPile = drawPile
        self.discardPile = discardPile
        self.activeColor = activeColor
        self.pendingDrawCount = pendingDrawCount
        self.winnerID = winnerID
    }
}
