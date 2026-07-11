import SwiftUI

struct MultiplayerSetupView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Multiplayer")
                .font(.largeTitle.bold())

            Text("Play nearby via Bluetooth & Wi-Fi\nNo internet needed — works on a plane ✈️")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                modeButton(
                    title: "Create a Game Room",
                    subtitle: "Host a room and pick the UNO variety",
                    icon: "plus.circle.fill",
                    action: .createRoom
                )

                modeButton(
                    title: "Join a Game Room",
                    subtitle: "Find nearby rooms automatically",
                    icon: "antenna.radiowaves.left.and.right",
                    action: .joinRoom
                )
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
        Button {
            app.selectMultiplayerAction(action)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MultiplayerSetupView()
            .environmentObject(AppViewModel())
    }
}
