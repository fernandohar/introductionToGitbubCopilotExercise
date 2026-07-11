import Foundation
import MultipeerConnectivity
import UIKit

/// Peer-to-peer multiplayer over Bluetooth and Wi-Fi — works offline (e.g. on an airplane).
final class MultipeerGameSession: NSObject, GameSession {
    weak var delegate: GameSessionDelegate?

    let localPlayerID: UUID
    private(set) var connectionState: ConnectionState = .disconnected
    var isHost: Bool { hostMode }

    private let serviceType = "uno-game"
    private var peerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var hostMode = false
    private var localPlayerName = ""
    private var gameState = GameState()
    private var variant: UnoVariant = .classic
    private var connectedPeers: [MCPeerID: UUID] = [:]

    override init() {
        localPlayerID = UUID()
        peerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    func hostGame(displayName: String) {
        disconnect()
        localPlayerName = displayName
        hostMode = true

        let localPlayer = Player(id: localPlayerID, displayName: displayName, isHost: true)
        gameState = GameState(phase: .lobby, players: [localPlayer])

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["game": "uno"], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        connectionState = .hosting
        delegate?.session(self, didChange: .hosting)
        broadcastLobby()
    }

    func joinGame(displayName: String) {
        disconnect()
        localPlayerName = displayName
        hostMode = false

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        connectionState = .connecting
        delegate?.session(self, didChange: .connecting)
    }

    func selectVariant(_ variant: UnoVariant) {
        guard hostMode else { return }
        self.variant = variant
        gameState.variantID = variant.id
        send(.selectVariant(variantID: variant.id))
        broadcastLobby()
    }

    func enterRulesPhase() {
        guard hostMode else { return }
        gameState.phase = .rulesReady
        gameState.readyDeadline = Date().addingTimeInterval(TimeInterval(variant.deck.readyTimeLimit))
        send(.enterRulesPhase)
        publishState()
    }

    func setReady() {
        send(.setReady(playerID: localPlayerID))
        if hostMode {
            applyReady(localPlayerID)
        }
    }

    func startGame(variant: UnoVariant) {
        guard hostMode else { return }
        self.variant = variant
        do {
            gameState = try UnoEngine.startGame(players: gameState.players, variant: variant)
            send(.gameState(gameState))
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    func sendPlayCard(cardID: UUID, chosenColor: CardColor?) {
        send(.playCard(cardID: cardID, chosenColor: chosenColor))
        if hostMode {
            handlePlayCard(cardID: cardID, chosenColor: chosenColor, playerID: localPlayerID)
        }
    }

    func sendDrawCard() {
        send(.drawCard)
        if hostMode {
            handleDrawCard(playerID: localPlayerID)
        }
    }

    func handleTurnTimeout() {
        send(.turnTimeout(playerID: localPlayerID))
        if hostMode, let current = gameState.currentPlayer {
            try? UnoEngine.handleTurnTimeout(for: current.id, in: &gameState, variant: variant)
            publishState()
        }
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        connectedPeers.removeAll()
        hostMode = false
        connectionState = .disconnected
        delegate?.session(self, didChange: .disconnected)
    }

    private func broadcastLobby() {
        let message = GameMessage.lobbyUpdate(players: gameState.players, variantID: gameState.variantID)
        send(message)
        delegate?.session(self, didReceive: message)
    }

    private func publishState() {
        delegate?.session(self, didReceive: .gameState(gameState))
        if hostMode {
            send(.gameState(gameState))
        }
    }

    private func send(_ message: GameMessage) {
        guard let session else { return }

        let peers = session.connectedPeers
        let shouldSendLocally: Bool = {
            switch message {
            case .lobbyUpdate, .gameState, .error: return true
            default: return false
            }
        }()

        if peers.isEmpty {
            if shouldSendLocally {
                delegate?.session(self, didReceive: message)
            }
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    private func handle(_ message: GameMessage, from peer: MCPeerID?) {
        switch message {
        case let .joinLobby(playerName):
            guard hostMode, let peer else { return }
            let player = Player(displayName: playerName)
            connectedPeers[peer] = player.id
            gameState.players.append(player)
            broadcastLobby()

        case let .lobbyUpdate(players, variantID):
            gameState.players = players
            gameState.variantID = variantID
            delegate?.session(self, didReceive: message)

        case let .selectVariant(variantID):
            gameState.variantID = variantID
            delegate?.session(self, didReceive: message)

        case .enterRulesPhase:
            gameState.phase = .rulesReady
            gameState.readyDeadline = Date().addingTimeInterval(TimeInterval(variant.deck.readyTimeLimit))
            delegate?.session(self, didReceive: message)
            publishState()

        case let .setReady(playerID):
            guard hostMode else { return }
            applyReady(playerID)

        case let .gameState(state):
            gameState = state
            delegate?.session(self, didReceive: message)

        case let .playCard(cardID, chosenColor):
            guard hostMode else { return }
            let playerID = playerID(for: peer) ?? localPlayerID
            handlePlayCard(cardID: cardID, chosenColor: chosenColor, playerID: playerID)

        case .drawCard:
            guard hostMode else { return }
            let playerID = playerID(for: peer) ?? localPlayerID
            handleDrawCard(playerID: playerID)

        case let .turnTimeout(playerID):
            guard hostMode else { return }
            try? UnoEngine.handleTurnTimeout(for: playerID, in: &gameState, variant: variant)
            publishState()

        case let .playerDisconnected(playerID):
            gameState.players.removeAll { $0.id == playerID }
            delegate?.session(self, didReceive: message)

        case .error, .startGame:
            delegate?.session(self, didReceive: message)
        }
    }

    private func applyReady(_ playerID: UUID) {
        guard let index = gameState.players.firstIndex(where: { $0.id == playerID }) else { return }
        gameState.players[index].isReady = true
        publishState()

        let readyCount = gameState.players.filter(\.isReady).count
        let timedOut = gameState.readyDeadline.map { Date() >= $0 } ?? false

        if gameState.allPlayersReady || (timedOut && readyCount >= UnoEngine.minPlayers) {
            startGame(variant: variant)
        }
    }

    private func handlePlayCard(cardID: UUID, chosenColor: CardColor?, playerID: UUID) {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == playerID }),
              let card = gameState.players[playerIndex].hand.first(where: { $0.id == cardID }) else { return }

        do {
            try UnoEngine.play(card: card, chosenColor: chosenColor, from: playerID, in: &gameState, variant: variant)
            publishState()
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    private func handleDrawCard(playerID: UUID) {
        do {
            if gameState.pendingDrawCount > 0 {
                try UnoEngine.drawPendingCards(for: playerID, in: &gameState, variant: variant)
            } else {
                _ = try UnoEngine.drawCard(for: playerID, in: &gameState, variant: variant)
            }
            publishState()
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    private func playerID(for peer: MCPeerID?) -> UUID? {
        guard let peer else { return nil }
        if peer == peerID { return localPlayerID }
        return connectedPeers[peer]
    }
}

extension MultipeerGameSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            if !hostMode {
                connectionState = .connected
                delegate?.session(self, didChange: .connected)
                send(.joinLobby(playerName: localPlayerName))
            } else {
                broadcastLobby()
            }
        case .notConnected:
            if let playerID = connectedPeers[peerID] {
                gameState.players.removeAll { $0.id == playerID }
                connectedPeers.removeValue(forKey: peerID)
                delegate?.session(self, didReceive: .playerDisconnected(playerID: playerID))
                if hostMode { broadcastLobby() }
            }
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(GameMessage.self, from: data) else { return }
        handle(message, from: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerGameSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension MultipeerGameSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
