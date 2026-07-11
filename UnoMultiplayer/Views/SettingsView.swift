import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        Form {
            Section("Player") {
                TextField("Display Name", text: $app.playerName)
            }

            Section("Game Catalog") {
                TextField("Catalog URL", text: Binding(
                    get: { app.catalogService.remoteCatalogURL },
                    set: { app.catalogService.remoteCatalogURL = $0 }
                ))
                    .font(.caption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { await app.catalogService.fetchLatestGames() }
                } label: {
                    HStack {
                        Label("Get Latest Games", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        if app.catalogService.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(app.catalogService.isLoading)

                Text("\(app.catalogService.variants.count) games available")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = app.catalogService.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("For Developers") {
                Text("Add new UNO varieties by editing GameCatalog/catalog.json in the GitHub repo. Players fetch updates from Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Done") {
                    app.screen = .home
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppViewModel())
    }
}
