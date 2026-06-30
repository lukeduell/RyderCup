import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var selectedTab: Tab = .leaderboard

    enum Tab: Hashable { case leaderboard, round, teams, sideGames, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { LeaderboardView() }
                .tabItem { Label("Board", systemImage: "trophy.fill") }
                .tag(Tab.leaderboard)

            NavigationStack { RoundView(roundIndex: vm.activeRoundIndex) }
                .tabItem { Label("Round", systemImage: "flag.fill") }
                .tag(Tab.round)

            NavigationStack { TeamsView() }
                .tabItem { Label("Teams", systemImage: "person.2.fill") }
                .tag(Tab.teams)

            NavigationStack { SideGamesView() }
                .tabItem { Label("Side Games", systemImage: "star.fill") }
                .tag(Tab.sideGames)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .refreshable { await vm.refreshOnce() }
    }
}
