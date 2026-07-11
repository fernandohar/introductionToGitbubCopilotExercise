import Foundation

enum GamePhase: String, Codable {
    case lobby
    case rulesReady
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
    var drawPile: [PlayingCard]
    var tableCards: [PlayingCard]
    var dealerHand: [PlayingCard]
    var sheddingDrawPile: [SheddingCard]
    var sheddingTable: [SheddingCard]
    var activeSheddingColor: SheddingColor?
    var pendingDrawCount: Int
    var winnerID: UUID?
    var gameID: String?
    var engineType: GameEngineType?
    var readyDeadline: Date?
    var turnDeadline: Date?
    var tableLabel: String?
    var passesInRow: Int
    var isTableOpen: Bool
    var blackjackStatus: String?

    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    var nextPlayer: Player? {
        guard !players.isEmpty else { return nil }
        let delta = direction.rawValue
        let nextIndex = (currentPlayerIndex + delta + players.count) % players.count
        return players[nextIndex]
    }

    var topCard: PlayingCard? { tableCards.last }
    var topSheddingCard: SheddingCard? { sheddingTable.last }

    var allPlayersReady: Bool {
        !players.isEmpty && players.allSatisfy(\.isReady)
    }

    var readySecondsRemaining: Int? {
        guard let readyDeadline else { return nil }
        return max(0, Int(readyDeadline.timeIntervalSinceNow))
    }

    var turnSecondsRemaining: Int? {
        guard let turnDeadline else { return nil }
        return max(0, Int(turnDeadline.timeIntervalSinceNow))
    }

    init(
        phase: GamePhase = .lobby,
        players: [Player] = [],
        currentPlayerIndex: Int = 0,
        direction: TurnDirection = .clockwise,
        drawPile: [PlayingCard] = [],
        tableCards: [PlayingCard] = [],
        dealerHand: [PlayingCard] = [],
        sheddingDrawPile: [SheddingCard] = [],
        sheddingTable: [SheddingCard] = [],
        activeSheddingColor: SheddingColor? = nil,
        pendingDrawCount: Int = 0,
        winnerID: UUID? = nil,
        gameID: String? = nil,
        engineType: GameEngineType? = nil,
        readyDeadline: Date? = nil,
        turnDeadline: Date? = nil,
        tableLabel: String? = nil,
        passesInRow: Int = 0,
        isTableOpen: Bool = false,
        blackjackStatus: String? = nil
    ) {
        self.phase = phase
        self.players = players
        self.currentPlayerIndex = currentPlayerIndex
        self.direction = direction
        self.drawPile = drawPile
        self.tableCards = tableCards
        self.dealerHand = dealerHand
        self.sheddingDrawPile = sheddingDrawPile
        self.sheddingTable = sheddingTable
        self.activeSheddingColor = activeSheddingColor
        self.pendingDrawCount = pendingDrawCount
        self.winnerID = winnerID
        self.gameID = gameID
        self.engineType = engineType
        self.readyDeadline = readyDeadline
        self.turnDeadline = turnDeadline
        self.tableLabel = tableLabel
        self.passesInRow = passesInRow
        self.isTableOpen = isTableOpen
        self.blackjackStatus = blackjackStatus
    }
}
