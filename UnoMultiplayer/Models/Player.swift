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

    init(
        id: UUID = UUID(),
        displayName: String,
        hand: [Card] = [],
        sheddingHand: [SheddingCard] = [],
        isHost: Bool = false,
        isConnected: Bool = true,
        isReady: Bool = false,
        isNPC: Bool = false,
        npcDifficulty: NPCDifficulty? = nil
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
    }

    var cardCount: Int { sheddingHand.isEmpty ? hand.count : sheddingHand.count }
    var hasWon: Bool { sheddingHand.isEmpty && hand.isEmpty }
}
