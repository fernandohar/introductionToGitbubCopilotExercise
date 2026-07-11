import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("🃏")
                    .font(.system(size: 72))
                Text("UNO")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                Text("Multiplayer Card Game")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                ForEach(PlayMode.allCases) { mode in
                    Button {
                        app.selectPlayMode(mode)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                    .font(.headline)
                                Text(mode.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                app.screen = .settings
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.subheadline)
            }
            .padding(.bottom)
        }
        .navigationTitle("")
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppViewModel())
    }
}
