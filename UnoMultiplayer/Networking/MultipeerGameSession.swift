import Foundation
import MultipeerConnectivity

/// Local multiplayer using Apple's Multipeer Connectivity framework.
/// Players on the same Wi-Fi network can discover and join games without a backend server.
final class MultipeerGameSession: NSObject, GameSession {
    weak var delegate: GameSessionDelegate?

    let localPlayerID: UUID
    private(set) var connectionState: ConnectionState = .disconnected

    private let serviceType = "uno-game"
    private var peerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var localPlayerName: String = ""
    private var isHost = false
    private var gameState = GameState()
    private var connectedPeers: [MCPeerID: UUID] = [:]

    override init() {
        localPlayerID = UUID()
        peerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    func hostGame(displayName: String) {
        disconnect()
        localPlayerName = displayName
        isHost = true

        let localPlayer = Player(id: localPlayerID, displayName: displayName, isHost: true)
        gameState = GameState(phase: .lobby, players: [localPlayer])

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        connectionState = .hosting
        delegate?.session(self, didChange: .hosting)
        broadcastLobby()
    }

    func joinGame(displayName: String, roomCode: String) {
        disconnect()
        localPlayerName = displayName
        isHost = false

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        connectionState = .connecting
        delegate?.session(self, didChange: .connecting)
    }

    func startGame() {
        guard isHost else { return }
        do {
            gameState = try UnoEngine.startGame(players: gameState.players)
            send(.gameState(gameState))
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    func sendPlayCard(cardID: UUID, chosenColor: CardColor?) {
        send(.playCard(cardID: cardID, chosenColor: chosenColor))
    }

    func sendDrawCard() {
        send(.drawCard)
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        connectedPeers.removeAll()
        connectionState = .disconnected
        delegate?.session(self, didChange: .disconnected)
    }

    private func broadcastLobby() {
        send(.lobbyUpdate(players: gameState.players))
    }

    private func send(_ message: GameMessage) {
        guard let session, !session.connectedPeers.isEmpty || isHost else {
            if case .lobbyUpdate = message {
                delegate?.session(self, didReceive: message)
            }
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            delegate?.session(self, didReceive: .error(error.localizedDescription))
        }
    }

    private func handle(_ message: GameMessage, from peer: MCPeerID?) {
        switch message {
        case let .joinLobby(playerName):
            guard isHost, let peer else { return }
            let player = Player(displayName: playerName)
            connectedPeers[peer] = player.id
            gameState.players.append(player)
            broadcastLobby()

        case .lobbyUpdate:
            delegate?.session(self, didReceive: message)

        case .startGame:
            break

        case let .gameState(state):
            gameState = state
            delegate?.session(self, didReceive: message)

        case let .playCard(cardID, chosenColor):
            guard isHost else { return }
            handlePlayCard(cardID: cardID, chosenColor: chosenColor, from: peer)

        case .drawCard:
            guard isHost else { return }
            handleDrawCard(from: peer)

        case let .playerDisconnected(playerID):
            gameState.players.removeAll { $0.id == playerID }
            delegate?.session(self, didReceive: message)

        case .error:
            delegate?.session(self, didReceive: message)
        }
    }

    private func handlePlayCard(cardID: UUID, chosenColor: CardColor?, from peer: MCPeerID?) {
        guard let peer, let playerID = connectedPeers[peer] ?? (peer == peerID ? localPlayerID : nil),
              let playerIndex = gameState.players.firstIndex(where: { $0.id == playerID }),
              let card = gameState.players[playerIndex].hand.first(where: { $0.id == cardID }) else { return }

        do {
            try UnoEngine.play(card: card, chosenColor: chosenColor, from: playerID, in: &gameState)
            send(.gameState(gameState))
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    private func handleDrawCard(from peer: MCPeerID?) {
        guard let peer, let playerID = connectedPeers[peer] ?? (peer == peerID ? localPlayerID : nil) else { return }

        do {
            if gameState.pendingDrawCount > 0 {
                try UnoEngine.drawPendingCards(for: playerID, in: &gameState)
            } else {
                _ = try UnoEngine.drawCard(for: playerID, in: &gameState)
            }
            send(.gameState(gameState))
        } catch {
            send(.error(error.localizedDescription))
        }
    }
}

extension MultipeerGameSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            if !isHost {
                connectionState = .connected
                delegate?.session(self, didChange: .connected)
                send(.joinLobby(playerName: localPlayerName))
            }
        case .notConnected:
            if let playerID = connectedPeers[peerID] {
                gameState.players.removeAll { $0.id == playerID }
                connectedPeers.removeValue(forKey: peerID)
                delegate?.session(self, didReceive: .playerDisconnected(playerID: playerID))
                if isHost { broadcastLobby() }
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
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

import UIKit
