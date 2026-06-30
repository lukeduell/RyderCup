import SwiftUI

struct RootView: View {
    @EnvironmentObject var vm: TournamentViewModel

    var body: some View {
        Group {
            if vm.apiBaseURL.isEmpty {
                APIConfigView()
            } else if vm.tournament == nil {
                JoinView()
            } else {
                MainTabView()
            }
        }
        .animation(.default, value: vm.tournament?.id)
    }
}
