import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var vm: TournamentViewModel

    var body: some View {
        List {
            if let t = vm.tournament {
                roundTeams(t, roundIndex: 1, title: "Friday — Best Ball Teams")
                roundTeams(t, roundIndex: 2, title: "Saturday AM — Scramble Teams")
            } else {
                Text("Loading…")
            }
        }
        .navigationTitle("Teams")
    }

    @ViewBuilder
    private func roundTeams(_ t: Tournament, roundIndex: Int, title: String) -> some View {
        let round = t.rounds.first(where: { $0.index == roundIndex })
        Section(title) {
            if let round, !round.teams.isEmpty {
                ForEach(round.teams) { team in
                    teamRow(team, players: t.players, matchups: round.matchups, teams: round.teams)
                }
            } else {
                Text("No teams yet.").foregroundStyle(.secondary)
            }
            NavigationLink {
                TeamEditView(roundIndex: roundIndex)
            } label: {
                Label("Edit teams manually", systemImage: "person.2.fill")
            }
            Button {
                Task {
                    if roundIndex == 1 { await vm.autoSeedR2Teams() }
                    else if roundIndex == 2 { await vm.autoSeedR3Teams() }
                }
            } label: {
                Label(round?.teams.isEmpty != false
                      ? (roundIndex == 1 ? "Seed from R1 results" : "Seed from running standings")
                      : "Re-seed automatically",
                      systemImage: "wand.and.stars")
            }
        }
    }

    @ViewBuilder
    private func teamRow(_ team: Team, players: [Player], matchups: [Matchup], teams: [Team]) -> some View {
        let names = team.playerIds.compactMap { id in players.first(where: { $0.id == id })?.name }
        let opponent: Team? = matchups
            .first(where: { $0.teamAId == team.id || $0.teamBId == team.id })
            .flatMap { m in teams.first(where: { $0.id == (m.teamAId == team.id ? m.teamBId : m.teamAId) }) }

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(team.name).font(.headline)
                if let seed = team.seedLabel {
                    Text(seed)
                        .font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
                Spacer()
                if let opp = opponent {
                    Text("vs \(opp.name)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            Text(names.joined(separator: " & "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
