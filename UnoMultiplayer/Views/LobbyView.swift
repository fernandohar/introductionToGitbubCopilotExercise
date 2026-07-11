import SwiftUI

struct LobbyView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var playerName = ""
    @State private var hasJoined = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "suit.club.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red, .primary)

            Text("Uno Multiplayer")
                .font(.largeTitle.bold())

            Text("Play with friends on the same Wi-Fi network")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !hasJoined {
                TextField("Your name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button("Host Game") {
                        viewModel.hostGame(name: playerName.isEmpty ? "Host" : playerName)
                        hasJoined = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Join Game") {
                        viewModel.joinGame(name: playerName.isEmpty ? "Player" : playerName)
                        hasJoined = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                connectionStatus

                if !viewModel.players.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Players (\(viewModel.players.count)/\(UnoEngine.maxPlayers))")
                            .font(.headline)

                        ForEach(viewModel.players) { player in
                            HStack {
                                Image(systemName: player.isHost ? "crown.fill" : "person.fill")
                                    .foregroundStyle(player.isHost ? .yellow : .secondary)
                                Text(player.displayName)
                                Spacer()
                                if player.id == viewModel.session.localPlayerID {
                                    Text("You")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if viewModel.isHost {
                    Button("Start Game") {
                        viewModel.startGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.players.count < UnoEngine.minPlayers)
                } else {
                    Text("Waiting for host to start...")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.top, 32)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var connectionStatus: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .hosting: .green
        case .connected, .connecting: .yellow
        case .disconnected: .red
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .hosting: "Hosting — waiting for players"
        case .connecting: "Searching for games..."
        case .connected: "Connected to host"
        case .disconnected: "Disconnected"
        }
    }
}

#Preview {
    LobbyView()
        .environmentObject(GameViewModel())
}
