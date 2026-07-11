import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("🏖️")
                    .font(.system(size: 64))
                Text("Card Cabana")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Classic card games, anywhere")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 14) {
                ForEach(PlayMode.allCases) { mode in
                    Button { app.selectPlayMode(mode) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                                Text(mode.subtitle).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding()
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button { app.screen = .settings } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.bottom)
        }
        .navigationTitle("")
    }
}
