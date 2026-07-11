import Foundation

/// Offline single-player session with local NPC opponents.
final class LocalGameSession: GameSession {
    weak var delegate: GameSessionDelegate?

    let localPlayerID: UUID
    private(set) var connectionState: ConnectionState = .disconnected
    var isHost: Bool { true }

    private var gameState = GameState()
    private var variant: UnoVariant = .classic
    private var npcTimer: Timer?

    init() {
        localPlayerID = UUID()
    }

    func hostGame(displayName: String) {
        connectionState = .hosting
        delegate?.session(self, didChange: .hosting)
    }

    func joinGame(displayName: String) {}

    func configureSinglePlayer(
        displayName: String,
        npcCount: Int,
        difficulty: NPCDifficulty,
        variant: UnoVariant
    ) {
        self.variant = variant
        var players = [Player(id: localPlayerID, displayName: displayName, isHost: true)]
        for index in 1 ... npcCount {
            players.append(
                Player(
                    displayName: "NPC \(index)",
                    isNPC: true,
                    npcDifficulty: difficulty
                )
            )
        }
        gameState = GameState(phase: .lobby, players: players, variantID: variant.id)
        connectionState = .hosting
        delegate?.session(self, didChange: .hosting)
        publishLobby()
    }

    func selectVariant(_ variant: UnoVariant) {
        self.variant = variant
        gameState.variantID = variant.id
        publishLobby()
    }

    func enterRulesPhase() {
        gameState.phase = .rulesReady
        gameState.readyDeadline = Date().addingTimeInterval(TimeInterval(variant.deck.readyTimeLimit))
        publishState()
    }

    func setReady() {
        guard let index = gameState.players.firstIndex(where: { $0.id == localPlayerID }) else { return }
        gameState.players[index].isReady = true
        publishState()

        let humans = gameState.players.filter { !$0.isNPC }
        if humans.allSatisfy(\.isReady) {
            startGame(variant: variant)
        }
    }

    func startGame(variant: UnoVariant) {
        self.variant = variant
        do {
            gameState = try UnoEngine.startGame(players: gameState.players, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendPlayCard(cardID: UUID, chosenColor: CardColor?) {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == localPlayerID }),
              let card = gameState.players[playerIndex].hand.first(where: { $0.id == cardID }) else { return }

        do {
            try UnoEngine.play(card: card, chosenColor: chosenColor, from: localPlayerID, in: &gameState, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendDrawCard() {
        do {
            if gameState.pendingDrawCount > 0 {
                try UnoEngine.drawPendingCards(for: localPlayerID, in: &gameState, variant: variant)
            } else {
                _ = try UnoEngine.drawCard(for: localPlayerID, in: &gameState, variant: variant)
            }
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func handleTurnTimeout() {
        guard gameState.phase == .inProgress else { return }
        guard let current = gameState.currentPlayer else { return }

        do {
            try UnoEngine.handleTurnTimeout(for: current.id, in: &gameState, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func disconnect() {
        npcTimer?.invalidate()
        npcTimer = nil
        gameState = GameState()
        connectionState = .disconnected
        delegate?.session(self, didChange: .disconnected)
    }

    private func publishLobby() {
        delegate?.session(self, didReceive: .lobbyUpdate(players: gameState.players, variantID: gameState.variantID))
    }

    private func publishState() {
        delegate?.session(self, didReceive: .gameState(gameState))
    }

    private func scheduleNPCTurnIfNeeded() {
        npcTimer?.invalidate()
        guard gameState.phase == .inProgress,
              let current = gameState.currentPlayer,
              current.isNPC,
              let difficulty = current.npcDifficulty else { return }

        let delay: TimeInterval = switch difficulty {
        case .easy: 1.5
        case .medium: 1.0
        case .hard: 0.6
        }

        npcTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performNPCTurn()
        }
    }

    private func performNPCTurn() {
        guard gameState.phase == .inProgress,
              let current = gameState.currentPlayer,
              current.isNPC,
              let difficulty = current.npcDifficulty else { return }

        if let move = NPCPlayer.chooseMove(for: current, in: gameState, variant: variant, difficulty: difficulty) {
            do {
                try UnoEngine.play(
                    card: move.card,
                    chosenColor: move.color,
                    from: current.id,
                    in: &gameState,
                    variant: variant
                )
            } catch {
                _ = try? UnoEngine.drawCard(for: current.id, in: &gameState, variant: variant)
            }
        } else if gameState.pendingDrawCount > 0 {
            try? UnoEngine.drawPendingCards(for: current.id, in: &gameState, variant: variant)
        } else {
            _ = try? UnoEngine.drawCard(for: current.id, in: &gameState, variant: variant)
        }

        publishState()
        scheduleNPCTurnIfNeeded()
    }
}
