import XCTest
@testable import UnoMultiplayer

final class SheddingRulesTests: XCTestCase {
    func testShowNoMercyEliminationAt22Cards() throws {
        let playerID = UUID()
        var players = [
            Player(id: playerID, displayName: "Alice", sheddingHand: [], isHost: true),
            Player(displayName: "Bob")
        ]

        let variant = GameVariant(
            id: "show-no-mercy",
            name: "Show No Mercy",
            tagline: "Test",
            icon: "💀",
            accentColor: "#B71C1C",
            rules: "Test",
            engineType: .shedding,
            settings: GameSettings(minPlayers: 2, maxPlayers: 10),
            theme: CardTheme(),
            sheddingDeck: SheddingDeckConfig(),
            sheddingRules: .showNoMercy
        )

        var state = try SheddingEngine.startGame(players: players, variant: variant)
        state.players[0].sheddingHand = (0 ..< 21).map { _ in SheddingCard(color: .red, value: .five) }
        state.currentPlayerIndex = 0

        let rules = variant.resolvedSheddingRules
        XCTAssertEqual(rules.maxHandBeforeElimination, 21)
        XCTAssertTrue(rules.allowStackingDraws)

        state.sheddingDrawPile = [SheddingCard(color: .blue, value: .one)]
        try SheddingEngine.drawCard(for: playerID, in: &state, variant: variant)

        XCTAssertTrue(state.players[0].isEliminated)
        XCTAssertTrue(state.players[0].sheddingHand.isEmpty)
    }

    func testRulesResolvedFromJSONFlags() {
        let variant = GameVariant(
            id: "colour-match-classic",
            name: "Classic",
            tagline: "Test",
            icon: "🃏",
            accentColor: "#E53935",
            rules: "Test",
            engineType: .shedding,
            settings: GameSettings(),
            theme: CardTheme(),
            sheddingDeck: SheddingDeckConfig(allowStackingDraws: true),
            sheddingRules: SheddingRules(requireOneLeftCall: true)
        )

        let rules = variant.resolvedSheddingRules
        XCTAssertTrue(rules.requireOneLeftCall)
        XCTAssertTrue(rules.allowStackingDraws)
    }

    func testGolfDeckHas54Faces() {
        XCTAssertEqual(GolfDeckFaces.all.count, 54)
    }
}
