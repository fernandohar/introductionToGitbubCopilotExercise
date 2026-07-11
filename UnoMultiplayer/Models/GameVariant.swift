import Foundation
import SwiftUI

enum GameEngineType: String, Codable, CaseIterable {
    case bigTwo
    case blackjack
    case shedding
}

struct GameSettings: Codable, Hashable {
    var minPlayers: Int = 2
    var maxPlayers: Int = 4
    var startingHandSize: Int = 0
    var turnTimeLimit: Int = 30
    var readyTimeLimit: Int = 300
}

struct CardTheme: Codable, Hashable {
    var hearts: String = "#E63946"
    var diamonds: String = "#E63946"
    var clubs: String = "#1D3557"
    var spades: String = "#1D3557"
    var cardBack: String = "#4A6FA5"
    var tableFelt: String = "#8FBC8F"

    func suitColor(for suit: CardSuit) -> Color {
        switch suit {
        case .hearts: Color(hex: hearts)
        case .diamonds: Color(hex: diamonds)
        case .clubs: Color(hex: clubs)
        case .spades: Color(hex: spades)
        }
    }
}

struct GameVariant: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var tagline: String
    var icon: String
    var accentColor: String
    var rules: String
    var engineType: GameEngineType
    var settings: GameSettings
    var theme: CardTheme
    var source: GameSource?
    var sheddingDeck: SheddingDeckConfig?
    var sheddingTheme: SheddingTheme?

    var accentSwiftUIColor: Color { Color(hex: accentColor) }
    var isDownloadable: Bool { source == .downloadable }
}

enum GameSource: String, Codable {
    case bundled
    case downloadable
}

    static let bigTwo = GameVariant(
        id: "big-two",
        name: "Big Two",
        tagline: "Cho Dai Di — Hong Kong classic",
        icon: "🀄",
        accentColor: "#E63946",
        rules: """
        Big Two (Cho Dai Di / Dai Di) is a climbing card game popular in Hong Kong.

        • Uses a standard 52-card deck; 3♦ is the lowest, 2 is the highest
        • Suit order: ♦ < ♣ < ♥ < ♠
        • 2–4 players; deal all cards evenly
        • Player holding 3♦ leads the first trick
        • Play a single card that beats the card on the table, or pass
        • First player to empty their hand wins
        """,
        engineType: .bigTwo,
        settings: GameSettings(minPlayers: 2, maxPlayers: 4, turnTimeLimit: 30, readyTimeLimit: 300),
        theme: CardTheme(),
        source: .bundled
    )
}

struct GameCatalog: Codable {
    var version: Int
    var games: [GameVariant]
}

// Backward-compatible alias
typealias UnoVariant = GameVariant

extension GameCatalog {
    var variants: [GameVariant] { games }
    init(version: Int, variants: [GameVariant]) {
        self.version = version
        self.games = variants
    }
}
