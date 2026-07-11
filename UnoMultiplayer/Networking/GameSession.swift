import Foundation

enum GameMessage: Codable {
    case joinLobby(playerName: String)
    case lobbyUpdate(players: [Player], variantID: String?)
    case selectVariant(variantID: String)
    case enterRulesPhase
    case setReady(playerID: UUID)
    case startGame
    case gameState(GameState)
    case playCard(cardID: UUID, chosenColor: CardColor?)
    case drawCard
    case turnTimeout(playerID: UUID)
    case playerDisconnected(playerID: UUID)
    case error(String)
}

protocol GameSessionDelegate: AnyObject {
    func session(_ session: GameSession, didReceive message: GameMessage)
    func session(_ session: GameSession, didChange connectionState: ConnectionState)
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case hosting
}

protocol GameSession: AnyObject {
    var delegate: GameSessionDelegate? { get set }
    var localPlayerID: UUID { get }
    var connectionState: ConnectionState { get }
    var isHost: Bool { get }

    func hostGame(displayName: String)
    func joinGame(displayName: String)
    func selectVariant(_ variant: UnoVariant)
    func enterRulesPhase()
    func setReady()
    func startGame(variant: UnoVariant)
    func sendPlayCard(cardID: UUID, chosenColor: CardColor?)
    func sendDrawCard()
    func handleTurnTimeout()
    func disconnect()
}
