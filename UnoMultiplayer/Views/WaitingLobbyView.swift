import SwiftUI

struct WaitingLobbyView: View {
    @EnvironmentObject private var app: AppViewModel

    private var maxPlayers: Int {
        app.selectedGame?.settings.maxPlayers ?? 4
    }

    var body: some View {
        VStack(spacing: 24) {
            connectionBadge

            if let game = app.selectedGame {
                HStack {
                    Text(game.icon).font(.title)
                    VStack(alignment: .leading) {
                        Text(game.name).font(.headline)
                        Text(game.tagline).font(.caption).foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Players (\(app.players.count)/\(maxPlayers))")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(app.players) { player in
                    HStack {
                        Image(systemName: player.isHost ? "crown.fill" : "person.fill")
                            .foregroundStyle(player.isHost ? AppTheme.nextBadge : AppTheme.textSecondary)
                        Text(player.displayName)
                        Spacer()
                        if player.id == app.localPlayer?.id {
                            Text("You").font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if app.isHost {
                Button("Show Rules & Ready Up") { app.proceedToRules() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(app.players.count < (app.selectedGame?.settings.minPlayers ?? 2))
            } else {
                Text("Waiting for host to start...")
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.top)
        .navigationTitle("Game Lobby")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") { app.goHome() }
            }
        }
    }

    private var connectionBadge: some View {
        HStack {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.surface, in: Capsule())
    }

    private var statusColor: Color {
        switch app.connectionState {
        case .hosting: AppTheme.primary
        case .connected, .connecting: AppTheme.accent
        case .disconnected: AppTheme.timerUrgent
        }
    }

    private var statusText: String {
        switch app.connectionState {
        case .hosting: "Hosting — nearby players can join"
        case .connecting: "Searching for nearby rooms..."
        case .connected: "Connected to room"
        case .disconnected: "Disconnected"
        }
    }
}
