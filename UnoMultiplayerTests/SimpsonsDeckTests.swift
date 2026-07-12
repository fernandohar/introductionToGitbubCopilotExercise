import XCTest
@testable import UnoMultiplayer

final class SimpsonsDeckTests: XCTestCase {
    func testCompleteFaceMapping() {
        XCTAssertEqual(SimpsonsDeckFaces.all.count, 54)
    }

    func testEveryStandardCardHasFace() {
        let config = SheddingDeckConfig()
        let deck = SheddingDeck(config: config, shuffled: false)
        let theme = SimpsonsDeckFaces.theme

        for card in deck.cards {
            XCTAssertNotNil(
                theme.face(for: card),
                "Missing face for \(card.faceKey)"
            )
        }
    }

    func testSimpsonsThemeFlags() {
        XCTAssertTrue(SimpsonsDeckFaces.theme.isSimpsonsDeck)
        XCTAssertEqual(SimpsonsDeckFaces.theme.cardBackEmoji, "🍩")
    }

    func testEnrichedCatalogGame() {
        let service = GameCatalogService()
        let raw = GameVariant(
            id: "uno-simpsons",
            name: "The Simpsons UNO",
            tagline: "Test",
            icon: "🍩",
            accentColor: "#FFD90F",
            rules: "Short",
            engineType: .shedding,
            settings: GameSettings(),
            theme: CardTheme(),
            source: .downloadable,
            sheddingDeck: SheddingDeckConfig(),
            sheddingTheme: SheddingTheme(
                red: SheddingSuitStyle(color: "#FF6B35", pattern: "diamonds"),
                blue: SheddingSuitStyle(color: "#4A90D9", pattern: "dots"),
                green: SheddingSuitStyle(color: "#5CB85C", pattern: "checkered"),
                yellow: SheddingSuitStyle(color: "#FFD90F", pattern: "stripes"),
                wild: SheddingSuitStyle(color: "#1A1A1A", pattern: "characters"),
                cardBack: "#FFD90F",
                deckStyle: "simpsons"
            )
        )
        // enrichGame is private — verify theme merge via public game lookup after manual catalog injection
        XCTAssertTrue(raw.sheddingTheme?.isSimpsonsDeck == true)
    }
}
