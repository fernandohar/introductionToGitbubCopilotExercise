import SwiftUI

struct MultiplayerSetupView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Multiplayer")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Play nearby via Bluetooth & Wi-Fi\nNo internet needed — works on a plane ✈️")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                modeButton(title: "Create a Game Room", subtitle: "Host a room and pick the game", icon: "plus.circle.fill", action: .createRoom)
                modeButton(title: "Join a Game Room", subtitle: "Find nearby rooms automatically", icon: "antenna.radiowaves.left.and.right", action: .joinRoom)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Multiplayer")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { app.goHome() }
            }
        }
    }

    private func modeButton(title: String, subtitle: String, icon: String, action: MultiplayerAction) -> some View {
        Button { app.selectMultiplayerAction(action) } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title).foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
