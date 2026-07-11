import Foundation

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var hand: [Card]
    var isHost: Bool
    var isConnected: Bool
    var isReady: Bool
    var isNPC: Bool
    var npcDifficulty: NPCDifficulty?

    init(
        id: UUID = UUID(),
        displayName: String,
        hand: [Card] = [],
        isHost: Bool = false,
        isConnected: Bool = true,
        isReady: Bool = false,
        isNPC: Bool = false,
        npcDifficulty: NPCDifficulty? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.hand = hand
        self.isHost = isHost
        self.isConnected = isConnected
        self.isReady = isReady
        self.isNPC = isNPC
        self.npcDifficulty = npcDifficulty
    }

    var cardCount: Int { hand.count }
    var hasUno: Bool { hand.count == 1 }
    var hasWon: Bool { hand.isEmpty }
}
