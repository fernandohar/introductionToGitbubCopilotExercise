import Foundation

/// Declarative rule profile for shedding (colour-matching) games.
/// Defined in JSON per game — the Swift engine interprets these flags.
struct SheddingRules: Codable, Hashable {
    /// Rule preset id: `classic`, `showNoMercy`, `golf`
    var profile: String = "classic"
    /// Eliminate a player when their hand exceeds this count (Show No Mercy: 21).
    var maxHandBeforeElimination: Int?
    /// Allow stacking +2 and +4 cards onto an existing draw penalty.
    var allowStackingDraws: Bool = false
    /// Require tapping "One left!" when holding a single card.
    var requireOneLeftCall: Bool = false
    /// Penalty cards drawn for forgetting the one-card call.
    var oneLeftPenaltyCards: Int = 2
    /// Jump-in: play an exact match out of turn (future).
    var jumpInEnabled: Bool = false
    /// 7 = swap hands, 0 = rotate all hands (future).
    var sevenZeroEnabled: Bool = false

    static let classic = SheddingRules()

    static let showNoMercy = SheddingRules(
        profile: "showNoMercy",
        maxHandBeforeElimination: 21,
        allowStackingDraws: true,
        requireOneLeftCall: true,
        jumpInEnabled: true,
        sevenZeroEnabled: true
    )

    static let golf = SheddingRules(
        profile: "golf",
        requireOneLeftCall: true
    )

    /// Merges explicit rules with legacy `SheddingDeckConfig.allowStackingDraws`.
    static func resolved(for variant: GameVariant) -> SheddingRules {
        var rules = variant.sheddingRules ?? SheddingRules()
        if variant.sheddingRules == nil,
           variant.sheddingDeck?.allowStackingDraws == true {
            rules.allowStackingDraws = true
        }
        return rules
    }
}
