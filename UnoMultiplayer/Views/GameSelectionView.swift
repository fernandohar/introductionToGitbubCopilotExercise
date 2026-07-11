import SwiftUI

struct GameSelectionView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var selectedID: String?

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose a Game")
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text(app.playMode == .singlePlayer
                 ? "Pick a card game to play"
                 : "Host: choose the game for your room")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(app.catalogService.games) { game in
                        gameCard(game)
                    }
                }
                .padding(.horizontal)
            }

            Button("Continue") {
                if let id = selectedID, let game = app.catalogService.game(id: id) {
                    app.selectGame(game)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .controlSize(.large)
            .disabled(selectedID == nil)
            .padding()
        }
        .navigationTitle("Games")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { app.goHome() }
            }
        }
    }

    private func gameCard(_ game: GameVariant) -> some View {
        let isSelected = selectedID == game.id

        return Button { selectedID = game.id } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.icon).font(.system(size: 36))
                Text(game.name).font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
                Text(game.tagline).font(.caption2).foregroundStyle(AppTheme.textSecondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? game.accentSwiftUIColor : .clear, lineWidth: 3))
            .shadow(color: isSelected ? game.accentSwiftUIColor.opacity(0.25) : .black.opacity(0.04), radius: 8)
        }
        .buttonStyle(.plain)
    }
}
