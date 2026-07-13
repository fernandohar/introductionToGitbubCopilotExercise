import Foundation

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var hand: [Card]
    var sheddingHand: [SheddingCard]
    var isHost: Bool
    var isConnected: Bool
    var isReady: Bool
    var isNPC: Bool
    var npcDifficulty: NPCDifficulty?
    var isEliminated: Bool
    var hasCalledOneLeft: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        hand: [Card] = [],
        sheddingHand: [SheddingCard] = [],
        isHost: Bool = false,
        isConnected: Bool = true,
        isReady: Bool = false,
        isNPC: Bool = false,
        npcDifficulty: NPCDifficulty? = nil,
        isEliminated: Bool = false,
        hasCalledOneLeft: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.hand = hand
        self.sheddingHand = sheddingHand
        self.isHost = isHost
        self.isConnected = isConnected
        self.isReady = isReady
        self.isNPC = isNPC
        self.npcDifficulty = npcDifficulty
        self.isEliminated = isEliminated
        self.hasCalledOneLeft = hasCalledOneLeft
    }

    var cardCount: Int { sheddingHand.isEmpty ? hand.count : sheddingHand.count }
    var hasWon: Bool { !isEliminated && sheddingHand.isEmpty && hand.isEmpty }
    var isActiveInSheddingGame: Bool { !isEliminated }
}
