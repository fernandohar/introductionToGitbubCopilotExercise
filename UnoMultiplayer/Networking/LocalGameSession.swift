import Foundation

/// Offline single-player session with local NPC opponents.
final class LocalGameSession: GameSession {
    weak var delegate: GameSessionDelegate?

    let localPlayerID: UUID
    private(set) var connectionState: ConnectionState = .disconnected
    var isHost: Bool { true }

    private var gameState = GameState()
    private var variant: GameVariant = .bigTwo
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
        variant: GameVariant
    ) {
        self.variant = variant
        var players = [Player(id: localPlayerID, displayName: displayName, isHost: true)]

        if variant.engineType == .blackjack {
            players.append(Player(displayName: "Dealer", isNPC: true, npcDifficulty: difficulty))
        } else {
            for index in 1 ... npcCount {
                players.append(
                    Player(displayName: "Player \(index)", isNPC: true, npcDifficulty: difficulty)
                )
            }
        }

        gameState = GameState(phase: .lobby, players: players, gameID: variant.id)
        connectionState = .hosting
        delegate?.session(self, didChange: .hosting)
        publishLobby()
    }

    func selectVariant(_ variant: GameVariant) {
        self.variant = variant
        gameState.gameID = variant.id
        publishLobby()
    }

    func enterRulesPhase() {
        gameState.phase = .rulesReady
        gameState.readyDeadline = Date().addingTimeInterval(TimeInterval(variant.settings.readyTimeLimit))
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

    func startGame(variant: GameVariant) {
        self.variant = variant
        do {
            gameState = try GameEngineRouter.startGame(players: gameState.players, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendPlayCard(cardID: UUID, chosenSheddingColor: SheddingColor? = nil) {
        do {
            switch variant.engineType {
            case .shedding:
                guard let playerIndex = gameState.players.firstIndex(where: { $0.id == localPlayerID }),
                      let card = gameState.players[playerIndex].sheddingHand.first(where: { $0.id == cardID }) else { return }
                try GameEngineRouter.playShedding(card: card, chosenColor: chosenSheddingColor, from: localPlayerID, in: &gameState, variant: variant)
            case .bigTwo:
                guard let playerIndex = gameState.players.firstIndex(where: { $0.id == localPlayerID }),
                      let card = gameState.players[playerIndex].hand.first(where: { $0.id == cardID }) else { return }
                try GameEngineRouter.play(card: card, from: localPlayerID, in: &gameState, variant: variant)
            case .blackjack:
                return
            }
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendDrawCard() {
        do {
            try GameEngineRouter.drawShedding(for: localPlayerID, in: &gameState, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendPass() {
        do {
            try GameEngineRouter.pass(from: localPlayerID, in: &gameState, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendHit() {
        do {
            try GameEngineRouter.hit(from: localPlayerID, in: &gameState, variant: variant)
            publishState()
            scheduleNPCTurnIfNeeded()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendStand() {
        do {
            try GameEngineRouter.stand(from: localPlayerID, in: &gameState, variant: variant)
            publishState()
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    func sendCallOneLeft() {
        GameEngineRouter.callOneLeft(for: localPlayerID, in: &gameState, variant: variant)
        publishState()
    }

    func handleTurnTimeout() {
        guard gameState.phase == .inProgress, let current = gameState.currentPlayer else { return }
        do {
            try GameEngineRouter.handleTurnTimeout(for: current.id, in: &gameState, variant: variant)
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
        delegate?.session(self, didReceive: .lobbyUpdate(players: gameState.players, gameID: gameState.gameID))
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

        switch variant.engineType {
        case .bigTwo:
            let move = NPCPlayer.chooseBigTwoMove(for: current, in: gameState, difficulty: difficulty)
            if move.shouldPass {
                try? GameEngineRouter.pass(from: current.id, in: &gameState, variant: variant)
            } else if let card = move.card {
                try? GameEngineRouter.play(card: card, from: current.id, in: &gameState, variant: variant)
            }
        case .blackjack:
            if NPCPlayer.chooseBlackjackAction(for: current, in: gameState, difficulty: difficulty) {
                try? GameEngineRouter.hit(from: current.id, in: &gameState, variant: variant)
            } else {
                try? GameEngineRouter.stand(from: current.id, in: &gameState, variant: variant)
            }
        case .shedding:
            let move = NPCPlayer.chooseSheddingMove(for: current, in: gameState, variant: variant, difficulty: difficulty)
            if let card = move.card {
                try? GameEngineRouter.playShedding(card: card, chosenColor: move.color, from: current.id, in: &gameState, variant: variant)
            } else if gameState.pendingDrawCount > 0 {
                try? SheddingEngine.drawPending(for: current.id, in: &gameState, variant: variant)
            } else {
                try? GameEngineRouter.drawShedding(for: current.id, in: &gameState, variant: variant)
            }
        }

        publishState()
        scheduleNPCTurnIfNeeded()
    }
}
