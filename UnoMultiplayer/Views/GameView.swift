import SwiftUI

struct GameView: View {
    @EnvironmentObject private var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let state = viewModel.gameState {
                opponentsView(state: state)
                discardPileView(state: state)
                handView
                actionBar(state: state)
            }
        }
        .padding()
        .sheet(isPresented: $viewModel.showColorPicker) {
            ColorPickerSheet { color in
                if let card = viewModel.selectedCard {
                    viewModel.playCard(card, color: color)
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Game Over!", isPresented: .constant(viewModel.gameState?.phase == .finished)) {
            Button("OK") {}
        } message: {
            if let winner = viewModel.gameState?.players.first(where: { $0.id == viewModel.gameState?.winnerID }) {
                Text("\(winner.displayName) wins!")
            }
        }
    }

    private func opponentsView(state: GameState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(state.players.filter { $0.id != viewModel.session.localPlayerID }) { player in
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(state.currentPlayer?.id == player.id ? .yellow : .secondary)
                        Text(player.displayName)
                            .font(.caption)
                        Text("\(player.cardCount) cards")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func discardPileView(state: GameState) -> some View {
        VStack(spacing: 8) {
            if let topCard = state.topCard {
                CardView(card: topCard, activeColor: state.activeColor)
                    .scaleEffect(1.2)
            }

            if let activeColor = state.activeColor, state.topCard?.isWild == true {
                Text("Active color: \(activeColor.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.pendingDrawCount > 0 {
                Text("Draw stack: +\(state.pendingDrawCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            if let current = state.currentPlayer {
                Text(current.id == viewModel.session.localPlayerID ? "Your turn" : "\(current.displayName)'s turn")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var handView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -20) {
                ForEach(viewModel.localPlayer?.hand ?? []) { card in
                    let isPlayable = viewModel.playableCards().contains(card)
                    CardView(card: card, isPlayable: isPlayable)
                        .onTapGesture {
                            guard viewModel.isMyTurn, isPlayable else { return }
                            viewModel.playCard(card)
                        }
                        .opacity(isPlayable || !viewModel.isMyTurn ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 140)
    }

    private func actionBar(state: GameState) -> some View {
        HStack {
            if viewModel.isMyTurn {
                Button("Draw Card") {
                    viewModel.drawCard()
                }
                .buttonStyle(.bordered)
            }

            if viewModel.localPlayer?.hasUno == true {
                Text("UNO!")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    GameView()
        .environmentObject(GameViewModel())
}
