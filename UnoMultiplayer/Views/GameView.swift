import SwiftUI

struct GameView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tableArea
            Spacer(minLength: 8)
            handArea
            actionBar
        }
        .sheet(isPresented: $app.showColorPicker) {
            ColorPickerSheet(theme: app.activeVariant?.theme) { color in
                if let card = app.selectedCard {
                    app.playCard(card, color: color)
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Game Over!", isPresented: .constant(app.gameState?.phase == .finished)) {
            Button("Home") { app.goHome() }
        } message: {
            if let winner = app.gameState?.players.first(where: { $0.id == app.gameState?.winnerID }) {
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
            if let variant = app.activeVariant {
                Text(variant.icon + " " + variant.name)
                    .font(.caption.bold())
            }
            Spacer()
            if let remaining = app.gameState?.turnSecondsRemaining {
                Label("\(remaining)s", systemImage: "timer")
                    .font(.caption.bold())
                    .foregroundStyle(remaining <= 5 ? .red : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var tableArea: some View {
        VStack(spacing: 16) {
            opponentsRow

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.green.opacity(0.15))
                    .frame(height: 200)

                VStack(spacing: 12) {
                    if let state = app.gameState {
                        HStack(spacing: 24) {
                            drawPileView(count: state.drawPile.count)
                            if let topCard = state.topCard {
                                CardView(
                                    card: topCard,
                                    activeColor: state.activeColor,
                                    theme: app.activeVariant?.theme
                                )
                                .scaleEffect(1.3)
                            }
                        }

                        if let activeColor = state.activeColor, state.topCard?.isWild == true {
                            Text("Color: \(activeColor.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if state.pendingDrawCount > 0 {
                            Text("Draw stack: +\(state.pendingDrawCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        }

                        if let current = state.currentPlayer {
                            Text(current.id == app.localPlayer?.id ? "Your turn" : "\(current.displayName)'s turn")
                                .font(.headline)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var opponentsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(app.gameState?.players.filter { $0.id != app.localPlayer?.id } ?? []) { player in
                    VStack(spacing: 4) {
                        Image(systemName: player.isNPC ? "cpu" : "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                app.gameState?.currentPlayer?.id == player.id ? .yellow : .secondary
                            )
                        Text(player.displayName)
                            .font(.caption2)
                        Text("\(player.cardCount)")
                            .font(.caption.bold())
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
        }
    }

    private func drawPileView(count: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.8))
                .frame(width: 72, height: 104)
            VStack {
                Image(systemName: "rectangle.stack.fill")
                Text("\(count)")
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
        }
    }

    private var handArea: some View {
        VStack(spacing: 8) {
            Text("Your Hand")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -16) {
                    ForEach(app.localPlayer?.hand ?? []) { card in
                        let isPlayable = app.playableCards().contains(card)
                        CardView(
                            card: card,
                            isPlayable: isPlayable && app.isMyTurn,
                            theme: app.activeVariant?.theme
                        )
                        .onTapGesture {
                            guard app.isMyTurn, isPlayable else { return }
                            app.playCard(card)
                        }
                        .opacity(isPlayable && app.isMyTurn ? 1 : 0.45)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 130)
        }
        .padding(.bottom, 8)
    }

    private var actionBar: some View {
        HStack {
            if app.isMyTurn {
                Button("Draw Card") {
                    app.drawCard()
                }
                .buttonStyle(.bordered)
            }

            if app.localPlayer?.hasUno == true {
                Text("UNO!")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
            }

            Spacer()

            Button("Leave") {
                app.goHome()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        GameView()
            .environmentObject(AppViewModel())
    }
}
