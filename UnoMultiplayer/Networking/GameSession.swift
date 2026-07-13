import Foundation

enum GameMessage: Codable {
    case joinLobby(playerName: String)
    case lobbyUpdate(players: [Player], gameID: String?)
    case selectVariant(gameID: String)
    case enterRulesPhase
    case setReady(playerID: UUID)
    case startGame
    case gameState(GameState)
    case playCard(cardID: UUID, chosenSheddingColor: SheddingColor?)
    case drawCard
    case pass
    case hit
    case stand
    case callOneLeft(playerID: UUID)
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
    func selectVariant(_ variant: GameVariant)
    func enterRulesPhase()
    func setReady()
    func startGame(variant: GameVariant)
    func sendPlayCard(cardID: UUID, chosenSheddingColor: SheddingColor? = nil)
    func sendDrawCard()
    func sendPass()
    func sendHit()
    func sendStand()
    func sendCallOneLeft()
    func handleTurnTimeout()
    func disconnect()
}
