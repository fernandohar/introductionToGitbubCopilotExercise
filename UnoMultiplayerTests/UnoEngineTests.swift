import XCTest
@testable import UnoMultiplayer

final class UnoEngineTests: XCTestCase {
    func testStartGameDealsSevenCards() throws {
        let players = [
            Player(displayName: "Alice", isHost: true),
            Player(displayName: "Bob")
        ]

        let state = try UnoEngine.startGame(players: players)

        XCTAssertEqual(state.phase, .inProgress)
        XCTAssertEqual(state.players.count, 2)
        XCTAssertEqual(state.players[0].hand.count, 7)
        XCTAssertEqual(state.players[1].hand.count, 7)
        XCTAssertFalse(state.discardPile.isEmpty)
    }

    func testPlayMatchingNumberCard() throws {
        var players = [
            Player(id: UUID(), displayName: "Alice", hand: [Card(color: .red, value: .five)], isHost: true),
            Player(displayName: "Bob")
        ]

        var state = GameState(
            phase: .inProgress,
            players: players,
            discardPile: [Card(color: .blue, value: .five)],
            activeColor: .blue
        )

        try UnoEngine.play(card: players[0].hand[0], from: players[0].id, in: &state)

        XCTAssertTrue(state.players[0].hand.isEmpty)
        XCTAssertEqual(state.phase, .finished)
        XCTAssertEqual(state.winnerID, players[0].id)
    }

    func testWildCardRequiresColor() {
        let player = Player(displayName: "Alice", hand: [Card(color: .wild, value: .wild)], isHost: true)
        var state = GameState(
            phase: .inProgress,
            players: [player],
            discardPile: [Card(color: .red, value: .three)],
            activeColor: .red
        )

        XCTAssertThrowsError(try UnoEngine.play(card: player.hand[0], from: player.id, in: &state)) { error in
            XCTAssertEqual(error as? UnoEngineError, .mustChooseColor)
        }
    }
}
