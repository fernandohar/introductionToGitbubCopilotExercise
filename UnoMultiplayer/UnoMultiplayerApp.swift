import SwiftUI

@main
struct UnoMultiplayerApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
