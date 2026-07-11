import Foundation
import SwiftUI

struct DeckConfiguration: Codable, Hashable {
    var allWild: Bool = false
    var includeSkip: Bool = true
    var includeReverse: Bool = true
    var includeDrawTwo: Bool = true
    var includeWild: Bool = true
    var includeWildDrawFour: Bool = true
    var allowStackingDraws: Bool = false
    var startingHandSize: Int = 7
    var turnTimeLimit: Int = 30
    var readyTimeLimit: Int = 300
}

struct CardTheme: Codable, Hashable {
    var red: String = "#E53935"
    var blue: String = "#1E88E5"
    var green: String = "#43A047"
    var yellow: String = "#FDD835"
    var wild: String = "#8E24AA"
    var cardStyle: String = "classic"

    func swiftUIColor(for color: CardColor) -> Color {
        let hex: String
        switch color {
        case .red: hex = red
        case .blue: hex = blue
        case .green: hex = green
        case .yellow: hex = yellow
        case .wild: hex = wild
        }
        return Color(hex: hex)
    }
}

struct UnoVariant: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var tagline: String
    var icon: String
    var accentColor: String
    var rules: String
    var deck: DeckConfiguration
    var theme: CardTheme

    var accentSwiftUIColor: Color { Color(hex: accentColor) }

    static let classic = UnoVariant(
        id: "classic",
        name: "UNO Classic",
        tagline: "The original card-matching game",
        icon: "🃏",
        accentColor: "#E53935",
        rules: """
        Match cards by color or number. Action cards:
        • Skip — next player loses a turn
        • Reverse — reverses play direction
        • Draw Two (+2) — next player draws 2 cards
        • Wild — choose the next color
        • Wild Draw Four (+4) — choose color, next player draws 4

        Say "UNO!" when you have one card left. First player to empty their hand wins.
        """,
        deck: DeckConfiguration(),
        theme: CardTheme()
    )
}

struct GameCatalog: Codable {
    var version: Int
    var variants: [UnoVariant]
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
