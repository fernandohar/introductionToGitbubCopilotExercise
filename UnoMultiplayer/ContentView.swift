import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch app.screen {
                case .home: HomeView()
                case .singlePlayerSetup: SinglePlayerSetupView()
                case .multiplayerSetup: MultiplayerSetupView()
                case .varietySelection: GameSelectionView()
                case .waitingLobby: WaitingLobbyView()
                case .rulesReady: RulesReadyView()
                case .game: GameView()
                case .settings: SettingsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .vacationBackground()
        }
        .tint(AppTheme.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
