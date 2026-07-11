import SwiftUI

struct RulesReadyView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let variant = app.activeVariant {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(variant.icon)
                                .font(.system(size: 48))
                            VStack(alignment: .leading) {
                                Text(variant.name)
                                    .font(.title2.bold())
                                Text(variant.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Text("Rules")
                            .font(.headline)

                        Text(variant.rules)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Divider()

                        Text("Game Settings")
                            .font(.headline)

                        Label("\(variant.deck.turnTimeLimit)s per turn", systemImage: "timer")
                        Label("Works offline via Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                        Label("Up to \(UnoEngine.maxPlayers) players", systemImage: "person.3")
                    }
                    .padding()
                }

                VStack(spacing: 12) {
                    if let remaining = app.gameState?.readySecondsRemaining {
                        HStack {
                            Image(systemName: "clock")
                            Text("Auto-start in \(formatTime(remaining))")
                                .font(.caption)
                                .foregroundStyle(remaining < 60 ? .red : .secondary)
                        }
                    }

                    readyPlayerList

                    Button {
                        app.toggleReady()
                    } label: {
                        HStack {
                            Text(localPlayerReady ? "👌 Ready!" : "👌 Ready")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(localPlayerReady ? Color.green.opacity(0.3) : Color.blue, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(localPlayerReady)
                }
                .padding()
                .background(.ultraThinMaterial)
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

    private var localPlayerReady: Bool {
        app.localPlayer?.isReady ?? false
    }

    private var readyPlayerList: some View {
        HStack(spacing: 8) {
            ForEach(app.players) { player in
                VStack(spacing: 4) {
                    Text(player.isReady ? "👌" : "⏳")
                        .font(.title2)
                    Text(player.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    NavigationStack {
        RulesReadyView()
            .environmentObject(AppViewModel())
    }
}
