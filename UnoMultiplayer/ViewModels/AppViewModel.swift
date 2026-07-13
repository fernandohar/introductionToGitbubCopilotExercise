import SwiftUI

@MainActor
final class AppViewModel: ObservableObject, GameSessionDelegate {
    @Published var screen: AppScreen = .home
    @Published var playMode: PlayMode?
    @Published var multiplayerAction: MultiplayerAction?
    @Published var selectedGame: GameVariant?
    @Published var npcDifficulty: NPCDifficulty = .medium
    @Published var npcCount: Int = 3
    @Published var useOnlineNPC: Bool = false

    @Published var connectionState: ConnectionState = .disconnected
    @Published var players: [Player] = []
    @Published var gameState: GameState?
    @Published var errorMessage: String?
    @Published var selectedSheddingCard: SheddingCard?
    @Published var showSheddingColorPicker = false

    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: "playerName") }
    }

    let catalogService: GameCatalogService
    private var session: GameSession
    private var turnTimer: Timer?
    private var readyTimer: Timer?

    var localPlayer: Player? {
        if let state = gameState {
            return state.players.first { $0.id == session.localPlayerID }
        }
        return players.first { $0.id == session.localPlayerID }
    }

    var isHost: Bool { session.isHost }
    var isMyTurn: Bool { gameState?.currentPlayer?.id == session.localPlayerID }

    var activeGame: GameVariant? {
        if let selectedGame {
            return catalogService.game(id: selectedGame.id) ?? selectedGame
        }
        if let id = gameState?.gameID { return catalogService.game(id: id) }
        return nil
    }

    init(catalogService: GameCatalogService = GameCatalogService()) {
        self.catalogService = catalogService
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? "Player"
        self.session = LocalGameSession()
        self.session.delegate = self
    }

    func goHome() {
        stopTimers()
        session.disconnect()
        screen = .home
        playMode = nil
        multiplayerAction = nil
        selectedGame = nil
        gameState = nil
        players = []
    }

    func selectPlayMode(_ mode: PlayMode) {
        playMode = mode
        screen = mode == .singlePlayer ? .singlePlayerSetup : .multiplayerSetup
    }

    func selectMultiplayerAction(_ action: MultiplayerAction) {
        multiplayerAction = action
        if action == .createRoom {
            session = MultipeerGameSession()
            session.delegate = self
            session.hostGame(displayName: playerName)
            screen = .varietySelection
        } else {
            session = MultipeerGameSession()
            session.delegate = self
            session.joinGame(displayName: playerName)
            screen = .waitingLobby
        }
    }

    func confirmSinglePlayerSetup() {
        screen = .varietySelection
        session = LocalGameSession()
        session.delegate = self
    }

    func selectGame(_ game: GameVariant) {
        selectedGame = game

        if playMode == .singlePlayer {
            let opponents = game.engineType == .blackjack ? 1 : npcCount
            (session as? LocalGameSession)?.configureSinglePlayer(
                displayName: playerName,
                npcCount: opponents,
                difficulty: npcDifficulty,
                variant: game
            )
            screen = .rulesReady
            session.enterRulesPhase()
        } else if multiplayerAction == .createRoom {
            session.selectVariant(game)
            screen = .waitingLobby
        } else {
            screen = .waitingLobby
        }
    }

    func proceedToRules() {
        guard selectedGame != nil || gameState?.gameID != nil else { return }
        if isHost { session.enterRulesPhase() }
        screen = .rulesReady
    }

    func toggleReady() { session.setReady() }

    func playCard(_ card: PlayingCard) {
        session.sendPlayCard(cardID: card.id)
    }

    func playSheddingCard(_ card: SheddingCard, color: SheddingColor? = nil) {
        if card.isWild && color == nil {
            selectedSheddingCard = card
            showSheddingColorPicker = true
            return
        }
        session.sendPlayCard(cardID: card.id, chosenSheddingColor: color)
        selectedSheddingCard = nil
        showSheddingColorPicker = false
    }

    func drawCard() { session.sendDrawCard() }

    func pass() { session.sendPass() }
    func hit() { session.sendHit() }
    func stand() { session.sendStand() }

    func callOneLeft() { session.sendCallOneLeft() }

    func playableCards() -> [PlayingCard] {
        guard let hand = localPlayer?.hand,
              let state = gameState,
              let game = activeGame else { return [] }
        return GameEngineRouter.playableCards(in: hand, for: state, variant: game)
    }

    func playableSheddingCards() -> [SheddingCard] {
        guard let hand = localPlayer?.sheddingHand,
              let state = gameState,
              let game = activeGame else { return [] }
        return GameEngineRouter.playableSheddingCards(in: hand, for: state, variant: game)
    }

    func canPass() -> Bool {
        playableCards().isEmpty && gameState?.topCard != nil
    }

    var hasOneCardLeft: Bool {
        localPlayer?.cardCount == 1
    }

    // MARK: - Session delegate

    nonisolated func session(_ session: GameSession, didReceive message: GameMessage) {
        Task { @MainActor in
            switch message {
            case let .lobbyUpdate(players, gameID):
                self.players = players
                if let gameID, self.selectedGame == nil {
                    self.selectedGame = self.catalogService.game(id: gameID)
                }

            case let .selectVariant(gameID):
                self.selectedGame = self.catalogService.game(id: gameID)

            case .enterRulesPhase:
                self.screen = .rulesReady
                self.startReadyTimer()

            case let .gameState(state):
                self.gameState = state
                self.players = state.players
                if state.phase == .inProgress {
                    self.screen = .game
                    self.startTurnTimer()
                } else if state.phase == .rulesReady {
                    self.screen = .rulesReady
                    self.startReadyTimer()
                } else if state.phase == .finished {
                    self.stopTimers()
                }

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

    private func startTurnTimer() {
        turnTimer?.invalidate()
        turnTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickTurnTimer() }
        }
    }

    private func tickTurnTimer() {
        guard gameState?.phase == .inProgress else { return }
        objectWillChange.send()
        guard isMyTurn, let remaining = gameState?.turnSecondsRemaining, remaining <= 0 else { return }
        session.handleTurnTimeout()
    }

    private func startReadyTimer() {
        readyTimer?.invalidate()
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickReadyTimer() }
        }
    }

    private func tickReadyTimer() {
        guard gameState?.phase == .rulesReady else { return }
        objectWillChange.send()

        if gameState?.allPlayersReady == true, isHost, let game = activeGame {
            session.startGame(variant: game)
            return
        }

        guard let deadline = gameState?.readyDeadline, Date() >= deadline, isHost, let game = activeGame else { return }
        session.startGame(variant: game)
    }

    private func stopTimers() {
        turnTimer?.invalidate()
        readyTimer?.invalidate()
        turnTimer = nil
        readyTimer = nil
    }
}
