import SwiftUI

@MainActor
final class GameViewModel: ObservableObject, GameSessionDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var players: [Player] = []
    @Published var gameState: GameState?
    @Published var errorMessage: String?
    @Published var selectedCard: Card?
    @Published var showColorPicker = false

    let session: GameSession

    var localPlayer: Player? {
        guard let state = gameState else {
            return players.first { $0.id == session.localPlayerID }
        }
        return state.players.first { $0.id == session.localPlayerID }
    }

    var isHost: Bool {
        localPlayer?.isHost ?? false
    }

    var isMyTurn: Bool {
        gameState?.currentPlayer?.id == session.localPlayerID
    }

    init(session: GameSession = MultipeerGameSession()) {
        self.session = session
        self.session.delegate = self
    }

    func hostGame(name: String) {
        session.hostGame(displayName: name)
    }

    func joinGame(name: String) {
        session.joinGame(displayName: name, roomCode: "")
    }

    func startGame() {
        session.startGame()
    }

    func playCard(_ card: Card, color: CardColor? = nil) {
        if card.isWild && color == nil {
            selectedCard = card
            showColorPicker = true
            return
        }
        session.sendPlayCard(cardID: card.id, chosenColor: color)
        selectedCard = nil
        showColorPicker = false
    }

    func drawCard() {
        session.sendDrawCard()
    }

    func playableCards() -> [Card] {
        guard let hand = localPlayer?.hand, let state = gameState else { return [] }
        return UnoEngine.playableCards(in: hand, for: state)
    }

    nonisolated func session(_ session: GameSession, didReceive message: GameMessage) {
        Task { @MainActor in
            switch message {
            case let .lobbyUpdate(players):
                self.players = players
            case let .gameState(state):
                self.gameState = state
                self.players = state.players
            case let .error(message):
                self.errorMessage = message
            case let .playerDisconnected(playerID):
                self.players.removeAll { $0.id == playerID }
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: GameSession, didChange connectionState: ConnectionState) {
        Task { @MainActor in
            self.connectionState = connectionState
        }
    }
}
