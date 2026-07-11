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

            if !app.catalogService.hasDownloadableGames {
                downloadBanner
            }

            ScrollView {
                if !app.catalogService.bundledOnlyGames.isEmpty {
                    sectionHeader("Included")
                    gameGrid(app.catalogService.bundledOnlyGames)
                }

                if app.catalogService.hasDownloadableGames {
                    sectionHeader("Downloaded")
                    gameGrid(app.catalogService.downloadableGames)
                }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await app.catalogService.fetchLatestGames() }
                } label: {
                    if app.catalogService.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                }
            }
        }
    }

    private var downloadBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("More games available online")
                    .font(.caption.bold())
                Text("Tap ↓ to download UNO & themed decks")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func gameGrid(_ games: [GameVariant]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(games) { game in
                gameCard(game)
            }
        }
        .padding(.horizontal)
    }

    private func gameCard(_ game: GameVariant) -> some View {
        let isSelected = selectedID == game.id

        return Button { selectedID = game.id } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(game.icon).font(.system(size: 36))
                    Spacer()
                    if game.isDownloadable {
                        Image(systemName: "cloud.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
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
