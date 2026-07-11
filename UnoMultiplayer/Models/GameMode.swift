import Foundation

enum PlayMode: String, Codable, CaseIterable, Identifiable {
    case singlePlayer
    case multiplayer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePlayer: "Single Player"
        case .multiplayer: "Multiplayer"
        }
    }

    var subtitle: String {
        switch self {
        case .singlePlayer: "Play against NPC opponents"
        case .multiplayer: "Create or join a room"
        }
    }

    var icon: String {
        switch self {
        case .singlePlayer: "person.fill"
        case .multiplayer: "person.3.fill"
        }
    }
}

enum MultiplayerAction: String, Codable {
    case createRoom
    case joinRoom
}

enum NPCDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .easy: "Plays randomly — great for learning"
        case .medium: "Uses basic strategy"
        case .hard: "Aggressive, tracks the table"
        }
    }
}

enum AppScreen: Hashable {
    case home
    case singlePlayerSetup
    case multiplayerSetup
    case varietySelection
    case waitingLobby
    case rulesReady
    case game
    case settings
}
