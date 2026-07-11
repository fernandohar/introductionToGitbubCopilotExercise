import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch app.screen {
                case .home:
                    HomeView()
                case .singlePlayerSetup:
                    SinglePlayerSetupView()
                case .multiplayerSetup:
                    MultiplayerSetupView()
                case .varietySelection:
                    VarietySelectionView()
                case .waitingLobby:
                    WaitingLobbyView()
                case .rulesReady:
                    RulesReadyView()
                case .game:
                    GameView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
