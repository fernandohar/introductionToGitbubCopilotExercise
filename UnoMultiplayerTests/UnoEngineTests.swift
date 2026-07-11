import XCTest
@testable import UnoMultiplayer

final class UnoEngineTests: XCTestCase {
    let variant = UnoVariant.classic

    func testStartGameDealsSevenCards() throws {
        let players = [
            Player(displayName: "Alice", isHost: true),
            Player(displayName: "Bob")
        ]

        let state = try UnoEngine.startGame(players: players, variant: variant)

        XCTAssertEqual(state.phase, .inProgress)
        XCTAssertEqual(state.players.count, 2)
        XCTAssertEqual(state.players[0].hand.count, 7)
        XCTAssertEqual(state.players[1].hand.count, 7)
        XCTAssertFalse(state.discardPile.isEmpty)
        XCTAssertNotNil(state.turnDeadline)
    }

    func testPlayMatchingNumberCard() throws {
        let playerID = UUID()
        var players = [
            Player(id: playerID, displayName: "Alice", hand: [Card(color: .red, value: .five)], isHost: true),
            Player(displayName: "Bob")
        ]

        var state = GameState(
            phase: .inProgress,
            players: players,
            discardPile: [Card(color: .blue, value: .five)],
            activeColor: .blue,
            variantID: variant.id
        )

        try UnoEngine.play(card: players[0].hand[0], from: playerID, in: &state, variant: variant)

        XCTAssertTrue(state.players[0].hand.isEmpty)
        XCTAssertEqual(state.phase, .finished)
        XCTAssertEqual(state.winnerID, playerID)
    }

    func testWildCardRequiresColor() {
        let playerID = UUID()
        let player = Player(id: playerID, displayName: "Alice", hand: [Card(color: .wild, value: .wild)], isHost: true)
        var state = GameState(
            phase: .inProgress,
            players: [player],
            discardPile: [Card(color: .red, value: .three)],
            activeColor: .red,
            variantID: variant.id
        )

        XCTAssertThrowsError(
            try UnoEngine.play(card: player.hand[0], from: playerID, in: &state, variant: variant)
        ) { error in
            XCTAssertEqual(error as? UnoEngineError, .mustChooseColor)
        }
    }

    func testAllWildVariantAllowsAnyCard() throws {
        let allWildVariant = UnoVariant(
            id: "test-all-wild",
            name: "Test",
            tagline: "Test",
            icon: "🃏",
            accentColor: "#000000",
            rules: "Test",
            deck: DeckConfiguration(allWild: true),
            theme: CardTheme()
        )

        let players = [Player(displayName: "A"), Player(displayName: "B")]
        let state = try UnoEngine.startGame(players: players, variant: allWildVariant)
        let hand = state.players[0].hand
        XCTAssertFalse(hand.isEmpty)
        let playable = UnoEngine.playableCards(in: hand, for: state, variant: allWildVariant)
        XCTAssertEqual(playable.count, hand.count)
    }
}
