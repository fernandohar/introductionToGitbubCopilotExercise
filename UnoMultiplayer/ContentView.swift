import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: GameViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.gameState?.phase == .inProgress || viewModel.gameState?.phase == .finished {
                    GameView()
                } else {
                    LobbyView()
                }
            }
            .navigationTitle("Uno")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameViewModel())
}
