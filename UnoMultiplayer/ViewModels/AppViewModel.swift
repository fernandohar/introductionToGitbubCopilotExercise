import SwiftUI

@MainActor
final class AppViewModel: ObservableObject, GameSessionDelegate {
    @Published var screen: AppScreen = .home
    @Published var playMode: PlayMode?
    @Published var multiplayerAction: MultiplayerAction?
    @Published var selectedVariant: UnoVariant?
    @Published var npcDifficulty: NPCDifficulty = .medium
    @Published var npcCount: Int = 3
    @Published var useOnlineNPC: Bool = false

    @Published var connectionState: ConnectionState = .disconnected
    @Published var players: [Player] = []
    @Published var gameState: GameState?
    @Published var errorMessage: String?
    @Published var selectedCard: Card?
    @Published var showColorPicker = false

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

    var isMyTurn: Bool {
        gameState?.currentPlayer?.id == session.localPlayerID
    }

    init(catalogService: GameCatalogService = GameCatalogService()) {
        self.catalogService = catalogService
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? "Player"
        self.session = LocalGameSession()
        self.session.delegate = self
    }

    // MARK: - Navigation

    func goHome() {
        stopTimers()
        session.disconnect()
        screen = .home
        playMode = nil
        multiplayerAction = nil
        selectedVariant = nil
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

    func selectVariant(_ variant: UnoVariant) {
        selectedVariant = variant

        if playMode == .singlePlayer {
            (session as? LocalGameSession)?.configureSinglePlayer(
                displayName: playerName,
                npcCount: npcCount,
                difficulty: npcDifficulty,
                variant: variant
            )
            screen = .rulesReady
            session.enterRulesPhase()
        } else if multiplayerAction == .createRoom {
            session.selectVariant(variant)
            screen = .waitingLobby
        } else {
            screen = .waitingLobby
        }
    }

    func proceedToRules() {
        guard selectedVariant != nil || gameState?.variantID != nil else { return }
        if isHost {
            session.enterRulesPhase()
        }
        screen = .rulesReady
    }

    func toggleReady() {
        session.setReady()
    }

    func startGameIfReady() {
        guard let variant = selectedVariant ?? catalogService.variant(id: gameState?.variantID ?? "") else { return }
        if isHost && (gameState?.allPlayersReady == true || readyTimedOut) {
            session.startGame(variant: variant)
        }
    }

    private var readyTimedOut: Bool {
        guard let deadline = gameState?.readyDeadline else { return false }
        return Date() >= deadline
    }

    // MARK: - Gameplay

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
        guard let hand = localPlayer?.hand,
              let state = gameState,
              let variant = selectedVariant ?? catalogService.variant(id: state.variantID ?? "") else { return [] }
        return UnoEngine.playableCards(in: hand, for: state, variant: variant)
    }

    var activeVariant: UnoVariant? {
        if let selectedVariant { return selectedVariant }
        if let id = gameState?.variantID { return catalogService.variant(id: id) }
        return nil
    }

    // MARK: - Session delegate

    nonisolated func session(_ session: GameSession, didReceive message: GameMessage) {
        Task { @MainActor in
            switch message {
            case let .lobbyUpdate(players, variantID):
                self.players = players
                if let variantID, self.selectedVariant == nil {
                    self.selectedVariant = self.catalogService.variant(id: variantID)
                }

            case let .selectVariant(variantID):
                self.selectedVariant = self.catalogService.variant(id: variantID)

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

    // MARK: - Timers

    private func startTurnTimer() {
        turnTimer?.invalidate()
        turnTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickTurnTimer()
            }
        }
    }

    private func tickTurnTimer() {
        guard gameState?.phase == .inProgress else { return }
        objectWillChange.send()

        guard isMyTurn,
              let remaining = gameState?.turnSecondsRemaining,
              remaining <= 0 else { return }

        session.handleTurnTimeout()
    }

    private func startReadyTimer() {
        readyTimer?.invalidate()
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickReadyTimer()
            }
        }
    }

    private func tickReadyTimer() {
        guard gameState?.phase == .rulesReady else { return }
        objectWillChange.send()

        if readyTimedOut {
            if isHost {
                startGameIfReady()
            }
        } else if gameState?.allPlayersReady == true, isHost {
            startGameIfReady()
        }
    }

    private func stopTimers() {
        turnTimer?.invalidate()
        readyTimer?.invalidate()
        turnTimer = nil
        readyTimer = nil
    }
}
