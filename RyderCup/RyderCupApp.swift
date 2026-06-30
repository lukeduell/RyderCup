import SwiftUI

@main
struct RyderCupApp: App {
    @StateObject private var viewModel = TournamentViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .onAppear { viewModel.start() }
                .preferredColorScheme(.dark)
        }
    }
}
