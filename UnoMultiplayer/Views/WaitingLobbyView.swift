import SwiftUI

struct WaitingLobbyView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            connectionBadge

            if let variant = app.selectedVariant {
                HStack {
                    Text(variant.icon)
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text(variant.name)
                            .font(.headline)
                        Text(variant.tagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Players (\(app.players.count)/\(UnoEngine.maxPlayers))")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(app.players) { player in
                    HStack {
                        Image(systemName: player.isHost ? "crown.fill" : "person.fill")
                            .foregroundStyle(player.isHost ? .yellow : .secondary)
                        Text(player.displayName)
                        if player.isNPC {
                            Text("NPC")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.3), in: Capsule())
                        }
                        Spacer()
                        if player.id == app.localPlayer?.id {
                            Text("You")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if app.isHost {
                Text("Nearby players can join via Bluetooth or Wi-Fi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Show Rules & Ready Up") {
                    app.proceedToRules()
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.players.count < UnoEngine.minPlayers)
            } else {
                Text("Waiting for host to start...")
                    .foregroundStyle(.secondary)

                if app.selectedVariant != nil {
                    Text("Rules screen will appear when host is ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusColor: Color {
        switch app.connectionState {
        case .hosting: .green
        case .connected, .connecting: .yellow
        case .disconnected: .red
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

#Preview {
    NavigationStack {
        WaitingLobbyView()
            .environmentObject(AppViewModel())
    }
}
