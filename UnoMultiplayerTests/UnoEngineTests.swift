import XCTest
@testable import UnoMultiplayer

final class GameEngineTests: XCTestCase {
    let bigTwo = GameVariant.bigTwo

    func testBigTwoStartsWithCards() throws {
        let players = [
            Player(displayName: "Alice", isHost: true),
            Player(displayName: "Bob")
        ]
        let state = try BigTwoEngine.startGame(players: players, variant: bigTwo)
        XCTAssertEqual(state.phase, .inProgress)
        XCTAssertEqual(state.players[0].hand.count, 26)
        XCTAssertNotNil(state.turnDeadline)
    }

    func testBlackjackDealsTwoCards() throws {
        let blackjack = GameVariant(
            id: "blackjack",
            name: "Blackjack",
            tagline: "Test",
            icon: "🂡",
            accentColor: "#2A9D8F",
            rules: "Test",
            engineType: .blackjack,
            settings: GameSettings(minPlayers: 1, maxPlayers: 1),
            theme: CardTheme()
        )
        let players = [Player(displayName: "You")]
        let state = try BlackjackEngine.startGame(players: players, variant: blackjack)
        XCTAssertEqual(state.players[0].hand.count, 2)
        XCTAssertEqual(state.dealerHand.count, 2)
    }

    func testBigTwoPlayRemovesCard() throws {
        let playerID = UUID()
        let card = PlayingCard(suit: .diamonds, rank: .three)
        var players = [
            Player(id: playerID, displayName: "Alice", hand: [card], isHost: true),
            Player(displayName: "Bob")
        ]
        var state = GameState(
            phase: .inProgress,
            players: players,
            engineType: .bigTwo,
            isTableOpen: true
        )

        try BigTwoEngine.play(card: card, from: playerID, in: &state, variant: bigTwo)
        XCTAssertTrue(state.players[0].hand.isEmpty)
        XCTAssertEqual(state.phase, .finished)
    }
}
