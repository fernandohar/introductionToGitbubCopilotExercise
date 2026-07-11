import SwiftUI

struct SinglePlayerSetupView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Single Player")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Opponent Difficulty")
                    .font(.headline)

                ForEach(NPCDifficulty.allCases) { difficulty in
                    Button { app.npcDifficulty = difficulty } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(difficulty.title).font(.subheadline.bold())
                                Text(difficulty.description).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            if app.npcDifficulty == difficulty {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.primary)
                            }
                        }
                        .padding()
                        .background(app.npcDifficulty == difficulty ? AppTheme.surfaceMuted : AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Opponents: \(app.npcCount)")
                    .font(.headline)
                Stepper("NPC count", value: $app.npcCount, in: 1 ... 3)
                    .labelsHidden()
                Text("Used for Big Two and other multi-player games")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal)

            Spacer()

            Button("Choose a Game") {
                app.confirmSinglePlayerSetup()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .controlSize(.large)
            .padding()
        }
        .navigationTitle("Single Player")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { app.goHome() }
            }
        }
    }
}
