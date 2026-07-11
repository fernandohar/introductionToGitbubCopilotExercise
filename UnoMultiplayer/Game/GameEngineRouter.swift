import Foundation

struct GameEngineRouter {
    static func startGame(players: [Player], variant: GameVariant) throws -> GameState {
        switch variant.engineType {
        case .bigTwo: return try BigTwoEngine.startGame(players: players, variant: variant)
        case .blackjack: return try BlackjackEngine.startGame(players: players, variant: variant)
        case .shedding: return try SheddingEngine.startGame(players: players, variant: variant)
        }
    }

    static func playableCards(in hand: [PlayingCard], for state: GameState, variant: GameVariant) -> [PlayingCard] {
        switch variant.engineType {
        case .bigTwo: return BigTwoEngine.playableCards(in: hand, for: state)
        case .blackjack, .shedding: return []
        }
    }

    static func playableSheddingCards(in hand: [SheddingCard], for state: GameState, variant: GameVariant) -> [SheddingCard] {
        SheddingEngine.playableCards(in: hand, for: state, config: variant.sheddingDeck ?? SheddingDeckConfig())
    }

    static func play(card: PlayingCard, from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .bigTwo: try BigTwoEngine.play(card: card, from: playerID, in: &state, variant: variant)
        case .blackjack, .shedding: throw GameEngineError.invalidCard
        }
    }

    static func playShedding(
        card: SheddingCard,
        chosenColor: SheddingColor? = nil,
        from playerID: UUID,
        in state: inout GameState,
        variant: GameVariant
    ) throws {
        try SheddingEngine.play(card: card, chosenColor: chosenColor, from: playerID, in: &state, variant: variant)
    }

    static func drawShedding(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        try SheddingEngine.drawCard(for: playerID, in: &state, variant: variant)
    }

    static func pass(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .bigTwo: try BigTwoEngine.pass(from: playerID, in: &state, variant: variant)
        case .blackjack, .shedding: throw GameEngineError.invalidCard
        }
    }

    static func hit(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        try BlackjackEngine.hit(from: playerID, in: &state, variant: variant)
    }

    static func stand(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        try BlackjackEngine.stand(from: playerID, in: &state, variant: variant)
    }

    static func handleTurnTimeout(for playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .bigTwo:
            if BigTwoEngine.playableCards(in: state.players.first { $0.id == playerID }?.hand ?? [], for: state).isEmpty {
                try pass(from: playerID, in: &state, variant: variant)
            } else if let card = state.players.first(where: { $0.id == playerID })?.hand.first {
                try play(card: card, from: playerID, in: &state, variant: variant)
            }
        case .blackjack:
            try stand(from: playerID, in: &state, variant: variant)
        case .shedding:
            try SheddingEngine.handleTurnTimeout(for: playerID, in: &state, variant: variant)
        }
    }

    static func resetTurnDeadline(in state: inout GameState, variant: GameVariant) {
        state.turnDeadline = Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit))
    }
}

enum GameEngineError: LocalizedError, Equatable {
    case notEnoughPlayers
    case notPlayersTurn
    case invalidCard
    case gameNotInProgress
    case mustPass
    case unsupportedEngine

    var errorDescription: String? {
        switch self {
        case .notEnoughPlayers: return "Not enough players to start."
        case .notPlayersTurn: return "It is not your turn."
        case .invalidCard: return "That card cannot be played."
        case .gameNotInProgress: return "The game is not in progress."
        case .mustPass: return "You must pass — no playable card."
        case .unsupportedEngine: return "This game engine is not supported."
        }
    }
}
