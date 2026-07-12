import SwiftUI

struct RulesReadyView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let game = app.activeGame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(for: game)

                        if game.sheddingTheme?.isSimpsonsDeck == true {
                            SimpsonsDeckPreview(theme: game.sheddingTheme)
                        }

                        Divider()

                        Text("Rules").font(.headline)
                        Text(displayRules(for: game))
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(4)

                        if game.sheddingTheme?.isSimpsonsDeck == true {
                            simpsonsColourGuide
                        }

                        Divider()

                        Label("\(game.settings.turnTimeLimit)s per turn", systemImage: "timer")
                        Label("Works offline via Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .padding()
                }

                readyFooter
            }
        }
        .navigationTitle("Rules")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") { app.goHome() }
            }
        }
    }

    private func header(for game: GameVariant) -> some View {
        HStack {
            Text(game.icon).font(.system(size: 48))
            VStack(alignment: .leading) {
                Text(game.name).font(.title2.bold())
                Text(game.tagline).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func displayRules(for game: GameVariant) -> String {
        if game.id == "uno-simpsons" { return SimpsonsDeckFaces.rules }
        return game.rules
    }

    private var simpsonsColourGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card Colours").font(.headline)
            HStack(spacing: 10) {
                colourChip("Blue", pattern: "dots", hex: "#4A90D9")
                colourChip("Green", pattern: "checkered", hex: "#5CB85C")
            }
            HStack(spacing: 10) {
                colourChip("Yellow", pattern: "stripes", hex: "#FFD90F")
                colourChip("Red", pattern: "diamonds", hex: "#FF6B35")
            }
        }
    }

    private func colourChip(_ name: String, pattern: String, hex: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: hex))
                .frame(width: 20, height: 28)
            VStack(alignment: .leading) {
                Text(name).font(.caption.bold())
                Text(pattern).font(.caption2).foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(8)
        .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 8))
    }

    private var readyFooter: some View {
        VStack(spacing: 12) {
            if let remaining = app.gameState?.readySecondsRemaining {
                Label("Auto-start in \(formatTime(remaining))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(remaining < 60 ? AppTheme.timerUrgent : AppTheme.textSecondary)
            }
            readyPlayerList
            Button { app.toggleReady() } label: {
                Text(localPlayerReady ? "👌 Ready!" : "👌 Ready")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(localPlayerReady ? AppTheme.primary.opacity(0.2) : AppTheme.primary, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(localPlayerReady ? AppTheme.primary : .white)
            }
            .buttonStyle(.plain)
            .disabled(localPlayerReady)
        }
        .padding()
        .background(AppTheme.surface)
    }

    private var localPlayerReady: Bool { app.localPlayer?.isReady ?? false }

    private var readyPlayerList: some View {
        HStack(spacing: 8) {
            ForEach(app.players) { player in
                VStack(spacing: 4) {
                    Text(player.isReady ? "👌" : "⏳").font(.title2)
                    Text(player.displayName).font(.caption2).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct SimpsonsDeckPreview: View {
    let theme: SheddingTheme?

    private let samples: [(SheddingColor, SheddingValue)] = [
        (.blue, .skip), (.green, .four), (.yellow, .drawTwo), (.red, .eight), (.wild, .wild)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deck Preview").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SheddingCardBackView(theme: theme)
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                        SheddingCardView(
                            card: SheddingCard(color: sample.0, value: sample.1),
                            theme: theme
                        )
                    }
                }
            }
        }
    }
}
