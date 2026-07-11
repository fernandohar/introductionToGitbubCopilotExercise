import SwiftUI

struct SinglePlayerSetupView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Single Player")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                Text("NPC Difficulty")
                    .font(.headline)

                ForEach(NPCDifficulty.allCases) { difficulty in
                    Button {
                        app.npcDifficulty = difficulty
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(difficulty.title)
                                    .font(.subheadline.bold())
                                Text(difficulty.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if app.npcDifficulty == difficulty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(
                            app.npcDifficulty == difficulty
                                ? Color.green.opacity(0.15)
                                : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
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
            }
            .padding(.horizontal)

            Toggle("Use online AI (requires internet)", isOn: $app.useOnlineNPC)
                .padding(.horizontal)
                .disabled(true)
                .opacity(0.6)

            Text("Online AI coming soon — local NPC works offline")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Choose UNO Variety") {
                app.confirmSinglePlayerSetup()
            }
            .buttonStyle(.borderedProminent)
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

#Preview {
    NavigationStack {
        SinglePlayerSetupView()
            .environmentObject(AppViewModel())
    }
}
