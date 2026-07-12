import SwiftUI

struct GameView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            playerSeatsRow
            tableArea
            Spacer(minLength: 4)
            handArea
            actionBar
        }
        .vacationBackground()
        .sheet(isPresented: $app.showSheddingColorPicker) {
            SheddingColorPickerSheet(theme: app.activeGame?.sheddingTheme) { color in
                if let card = app.selectedSheddingCard {
                    app.playSheddingCard(card, color: color)
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Game Over!", isPresented: .constant(app.gameState?.phase == .finished)) {
            Button("Home") { app.goHome() }
        } message: {
            if let status = app.gameState?.blackjackStatus {
                Text(status)
            } else if let winner = app.gameState?.players.first(where: { $0.id == app.gameState?.winnerID }) {
                Text("\(winner.displayName) wins!")
            }
        }
        .alert("Error", isPresented: .constant(app.errorMessage != nil)) {
            Button("OK") { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        HStack {
            if let game = app.activeGame {
                Label(game.name, systemImage: "leaf.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primary)
            }
            Spacer()
            if let remaining = app.gameState?.turnSecondsRemaining {
                Label("\(remaining)s", systemImage: "timer")
                    .font(.caption.bold())
                    .foregroundStyle(remaining <= 5 ? AppTheme.timerUrgent : AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface, in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var playerSeatsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(otherPlayers) { player in
                    PlayerSeatView(
                        player: player,
                        isCurrentTurn: app.gameState?.currentPlayer?.id == player.id,
                        isNext: app.gameState?.nextPlayer?.id == player.id,
                        theme: app.activeGame?.theme
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var otherPlayers: [Player] {
        app.gameState?.players.filter { $0.id != app.localPlayer?.id } ?? []
    }

    private var tableArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.tableFelt)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.tableBorder, lineWidth: 3)
                )
                .frame(height: 210)
                .padding(.horizontal)

            VStack(spacing: 10) {
                if let label = app.gameState?.tableLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.15), in: Capsule())
                }

                HStack(spacing: 28) {
                    if app.activeGame?.engineType == .blackjack {
                        dealerArea
                    } else if app.activeGame?.engineType == .shedding,
                              let count = app.gameState?.sheddingDrawPile.count, count > 0 {
                        sheddingDrawPileView(count: count)
                    } else if let drawCount = app.gameState?.drawPile.count, drawCount > 0 {
                        drawPileView(count: drawCount)
                    }

                    if app.activeGame?.engineType == .shedding, let top = app.gameState?.topSheddingCard {
                        SheddingCardView(card: top, theme: app.activeGame?.sheddingTheme)
                            .scaleEffect(1.15)
                    } else if let top = app.gameState?.topCard {
                        PlayingCardView(card: top, theme: app.activeGame?.theme)
                            .scaleEffect(1.15)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 56, height: 80)
                    }
                }

                if app.activeGame?.engineType == .shedding,
                   let activeColor = app.gameState?.activeSheddingColor,
                   app.gameState?.topSheddingCard?.isWild == true {
                    Text("Colour: \(activeColor.displayName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }

                if let pending = app.gameState?.pendingDrawCount, pending > 0 {
                    Text("Draw stack: +\(pending)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                if let current = app.gameState?.currentPlayer {
                    HStack(spacing: 6) {
                        if current.id == app.localPlayer?.id {
                            Text("Your turn")
                        } else {
                            Text("\(current.displayName)'s turn")
                        }
                        if let next = app.gameState?.nextPlayer, next.id != current.id {
                            Text("→")
                            Text(next.displayName)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppTheme.nextBadge, in: Capsule())
                                .font(.caption.bold())
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dealerArea: some View {
        VStack(spacing: 4) {
            Text("Dealer")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: -12) {
                ForEach(Array((app.gameState?.dealerHand ?? []).enumerated()), id: \.element.id) { index, card in
                    PlayingCardView(
                        card: card,
                        theme: app.activeGame?.theme,
                        faceDown: index == 1 && app.gameState?.phase == .inProgress
                    )
                }
            }
            if app.gameState?.phase == .finished {
                Text("Value: \(BlackjackEngine.handValue(app.gameState?.dealerHand ?? []))")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }

    private func drawPileView(count: Int) -> some View {
        ZStack {
            PlayingCardView(
                card: PlayingCard(suit: .spades, rank: .ace),
                faceDown: true
            )
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(4)
                .background(AppTheme.accent, in: Circle())
                .offset(x: 20, y: -30)
        }
    }

    private func sheddingDrawPileView(count: Int) -> some View {
        ZStack {
            SheddingCardBackView(theme: app.activeGame?.sheddingTheme)
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(4)
                .background(AppTheme.accent, in: Circle())
                .offset(x: 22, y: -34)
        }
    }

    private var handArea: some View {
        VStack(spacing: 8) {
            if let status = app.gameState?.blackjackStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("Your Hand")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)

            if app.activeGame?.engineType == .shedding {
                sheddingHandView
            } else {
                standardHandView
            }
        }
        .padding(.bottom, 4)
    }

    private var sheddingHandView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -10) {
                ForEach(app.localPlayer?.sheddingHand ?? []) { card in
                    let isPlayable = app.playableSheddingCards().contains(card)
                    SheddingCardView(
                        card: card,
                        theme: app.activeGame?.sheddingTheme,
                        isPlayable: isPlayable && app.isMyTurn
                    )
                    .onTapGesture {
                        guard app.isMyTurn, isPlayable else { return }
                        app.playSheddingCard(card)
                    }
                    .opacity(isPlayable && app.isMyTurn ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 100)
    }

    private var standardHandView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -10) {
                ForEach(app.localPlayer?.hand ?? []) { card in
                    let isPlayable = app.playableCards().contains(card)
                    PlayingCardView(
                        card: card,
                        isPlayable: isPlayable && app.isMyTurn,
                        theme: app.activeGame?.theme
                    )
                    .onTapGesture {
                        guard app.isMyTurn, isPlayable else { return }
                        app.playCard(card)
                    }
                    .opacity(isPlayable && app.isMyTurn ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 100)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if app.isMyTurn {
                switch app.activeGame?.engineType {
                case .blackjack:
                    Button("Hit") { app.hit() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                    Button("Stand") { app.stand() }
                        .buttonStyle(.bordered)
                case .bigTwo:
                    if app.canPass() {
                        Button("Pass") { app.pass() }
                            .buttonStyle(.bordered)
                    }
                case .shedding:
                    Button("Draw") { app.drawCard() }
                        .buttonStyle(.bordered)
                    if app.hasOneCardLeft {
                        Text("One left!")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accent)
                    }
                default:
                    EmptyView()
                }
            }
            Spacer()
            Button("Leave") { app.goHome() }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.surface)
    }
}

#Preview {
    NavigationStack {
        GameView()
            .environmentObject(AppViewModel())
    }
}
