import SwiftUI

enum AppTheme {
    // Vacation palette — light, relaxed, beachy
    static let background = Color(hex: "#F7F3EB")       // warm sand
    static let surface = Color(hex: "#FFFFFF")
    static let surfaceMuted = Color(hex: "#EDF6F5")     // soft sea foam
    static let primary = Color(hex: "#2A9D8F")          // ocean teal
    static let accent = Color(hex: "#F4A261")           // sunset coral
    static let textPrimary = Color(hex: "#3D3A35")      // warm charcoal
    static let textSecondary = Color(hex: "#7A756C")
    static let tableFelt = Color(hex: "#8FBC8F")        // soft palm green
    static let tableBorder = Color(hex: "#6EA86E")
    static let nextBadge = Color(hex: "#E9C46A")        // sunny gold
    static let timerUrgent = Color(hex: "#E76F51")

    static let cardBack = Color(hex: "#4A6FA5")         // ocean blue card backs
    static let cardFace = Color(hex: "#FFFDF8")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#E8F4F8"), Color(hex: "#F7F3EB")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
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

struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }
}

extension View {
    func vacationBackground() -> some View {
        modifier(ThemedBackground())
    }
}
