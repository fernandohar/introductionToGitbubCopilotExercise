import SwiftUI

struct PlayingCardView: View {
    let card: PlayingCard
    var isPlayable: Bool = true
    var theme: CardTheme?
    var faceDown: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(faceDown ? AppTheme.cardBack : AppTheme.cardFace)
                .frame(width: 56, height: 80)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            if faceDown {
                Image(systemName: "suit.heart.fill")
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                VStack(spacing: 2) {
                    Text(card.rank.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(card.suit.symbol)
                        .font(.system(size: 20))
                }
                .foregroundStyle(suitColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlayable ? AppTheme.accent : Color.clear, lineWidth: 2.5)
        )
    }

    private var suitColor: Color {
        if let theme { return theme.suitColor(for: card.suit) }
        return card.suit.isRed ? Color(hex: "#E63946") : Color(hex: "#1D3557")
    }
}

#Preview {
    HStack {
        PlayingCardView(card: PlayingCard(suit: .hearts, rank: .ace))
        PlayingCardView(card: PlayingCard(suit: .spades, rank: .two), isPlayable: true)
        PlayingCardView(card: PlayingCard(suit: .diamonds, rank: .three), faceDown: true)
    }
    .padding()
}
