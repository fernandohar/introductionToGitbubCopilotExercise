import SwiftUI

struct RulesReadyView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let game = app.activeGame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(game.icon).font(.system(size: 48))
                            VStack(alignment: .leading) {
                                Text(game.name).font(.title2.bold())
                                Text(game.tagline).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                        }

                        Divider()

                        Text("Rules").font(.headline)
                        Text(game.rules).font(.body).foregroundStyle(AppTheme.textSecondary)

                        Divider()

                        Label("\(game.settings.turnTimeLimit)s per turn", systemImage: "timer")
                        Label("Works offline via Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .padding()
                }

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
        }
        .navigationTitle("Rules")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") { app.goHome() }
            }
        }
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
