import Foundation

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

struct GameEngineRouter {
    static func startGame(players: [Player], variant: GameVariant) throws -> GameState {
        switch variant.engineType {
        case .bigTwo: return try BigTwoEngine.startGame(players: players, variant: variant)
        case .blackjack: return try BlackjackEngine.startGame(players: players, variant: variant)
        }
    }

    static func playableCards(in hand: [PlayingCard], for state: GameState, variant: GameVariant) -> [PlayingCard] {
        switch variant.engineType {
        case .bigTwo: return BigTwoEngine.playableCards(in: hand, for: state)
        case .blackjack: return []
        }
    }

    static func play(card: PlayingCard, from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .bigTwo: try BigTwoEngine.play(card: card, from: playerID, in: &state, variant: variant)
        case .blackjack: throw GameEngineError.invalidCard
        }
    }

    static func pass(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .bigTwo: try BigTwoEngine.pass(from: playerID, in: &state, variant: variant)
        case .blackjack: throw GameEngineError.invalidCard
        }
    }

    static func hit(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .blackjack: try BlackjackEngine.hit(from: playerID, in: &state, variant: variant)
        case .bigTwo: throw GameEngineError.invalidCard
        }
    }

    static func stand(from playerID: UUID, in state: inout GameState, variant: GameVariant) throws {
        switch variant.engineType {
        case .blackjack: try BlackjackEngine.stand(from: playerID, in: &state, variant: variant)
        case .bigTwo: throw GameEngineError.invalidCard
        }
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
        }
    }

    static func resetTurnDeadline(in state: inout GameState, variant: GameVariant) {
        state.turnDeadline = Date().addingTimeInterval(TimeInterval(variant.settings.turnTimeLimit))
    }
}
