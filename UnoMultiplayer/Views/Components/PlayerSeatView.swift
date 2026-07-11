import SwiftUI

struct CardBackStackPreview: View {
    let count: Int
    var maxVisible: Int = 4

    var body: some View {
        ZStack {
            ForEach(0 ..< min(count, maxVisible), id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.cardBack)
                    .frame(width: 28, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .offset(x: CGFloat(index) * 3, y: CGFloat(index) * -2)
            }
        }
        .frame(width: 28 + CGFloat(min(count, maxVisible) - 1) * 3,
               height: 38 + CGFloat(min(count, maxVisible) - 1) * 2)
        .overlay(alignment: .bottomTrailing) {
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(3)
                .background(AppTheme.accent, in: Circle())
                .offset(x: 6, y: 4)
        }
    }
}

struct PlayerSeatView: View {
    let player: Player
    let isCurrentTurn: Bool
    let isNext: Bool
    let theme: CardTheme?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: player.isNPC ? "cpu" : "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isCurrentTurn ? AppTheme.primary : AppTheme.textSecondary)

                    CardBackStackPreview(count: player.cardCount)

                    Text(player.displayName)
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.surface)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentTurn ? AppTheme.primary : Color.clear, lineWidth: 2)
                )

                if isNext {
                    Text("NEXT")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.nextBadge, in: Capsule())
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

#Preview {
    HStack {
        PlayerSeatView(
            player: Player(displayName: "Alex", hand: Array(repeating: PlayingCard(suit: .hearts, rank: .ace), count: 7)),
            isCurrentTurn: true,
            isNext: false,
            theme: nil
        )
        PlayerSeatView(
            player: Player(displayName: "Sam", hand: Array(repeating: PlayingCard(suit: .spades, rank: .king), count: 12)),
            isCurrentTurn: false,
            isNext: true,
            theme: nil
        )
    }
    .padding()
    .vacationBackground()
}
