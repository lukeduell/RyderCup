import SwiftUI

/// Manual team editor for any team-based round (best ball, scramble).
///
/// Lets the user:
///   - rename teams
///   - swap players between teams
///   - edit best-ball matchups
///   - add/remove teams entirely (default is 4)
struct TeamEditView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int

    @State private var teams: [Team] = []
    @State private var matchups: [Matchup] = []

    var body: some View {
        Form {
            if let t = vm.tournament, let round = vm.round(roundIndex) {
                ForEach($teams) { $team in
                    Section {
                        TextField("Team name", text: $team.name)
                        ForEach(0..<team.playerIds.count, id: \.self) { slot in
                            playerPicker(
                                for: $team,
                                slot: slot,
                                allPlayers: t.players,
                                teamId: team.id
                            )
                        }
                        Button {
                            team.playerIds.append("")
                        } label: {
                            Label("Add slot", systemImage: "plus.circle")
                        }
                        Button(role: .destructive) {
                            removeTeam(id: team.id)
                        } label: {
                            Label("Remove team", systemImage: "trash")
                        }
                    } header: {
                        HStack {
                            Text(team.name.isEmpty ? team.id : team.name)
                            Spacer()
                            if let seed = team.seedLabel { Text(seed).font(.caption.bold()) }
                        }
                    }
                }

                Section {
                    Button {
                        addTeam()
                    } label: { Label("Add team", systemImage: "plus") }
                } header: { Text("Teams (\(teams.count))") }

                if round.format == .bestBall {
                    Section("Best-ball matchups") {
                        ForEach($matchups) { $m in
                            HStack {
                                teamPicker(selection: $m.teamAId, label: "A").frame(maxWidth: .infinity)
                                Text("vs").foregroundStyle(.secondary)
                                teamPicker(selection: $m.teamBId, label: "B").frame(maxWidth: .infinity)
                                Button {
                                    matchups.removeAll { $0.teamAId == m.teamAId && $0.teamBId == m.teamBId }
                                } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                            }
                        }
                        Button { addMatchup() } label: { Label("Add matchup", systemImage: "plus") }
                    }
                }

                Section { Button("Save teams") { save() } }
            }
        }
        .navigationTitle("Teams")
        .onAppear { reset() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        if vm.round(roundIndex)?.format == .bestBall { await vm.autoSeedR2Teams() }
                        else { await vm.autoSeedR3Teams() }
                        reset()
                    }
                } label: { Image(systemName: "wand.and.stars") }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func playerPicker(
        for team: Binding<Team>,
        slot: Int,
        allPlayers: [Player],
        teamId: String
    ) -> some View {
        let currentId = team.wrappedValue.playerIds.indices.contains(slot)
            ? team.wrappedValue.playerIds[slot]
            : ""
        Picker("Player \(slot + 1)", selection: Binding(
            get: { currentId },
            set: { newValue in
                var ids = team.wrappedValue.playerIds
                if slot < ids.count { ids[slot] = newValue } else { ids.append(newValue) }
                team.wrappedValue.playerIds = ids
                // Ensure no player appears in two teams: clear duplicates elsewhere.
                if !newValue.isEmpty {
                    for j in teams.indices where teams[j].id != teamId {
                        teams[j].playerIds = teams[j].playerIds.map { $0 == newValue ? "" : $0 }
                    }
                }
            }
        )) {
            Text("—").tag("")
            ForEach(allPlayers) { p in Text(p.name).tag(p.id) }
        }
    }

    @ViewBuilder
    private func teamPicker(selection: Binding<String>, label: String) -> some View {
        Picker(label, selection: selection) {
            Text("—").tag("")
            ForEach(teams) { team in Text(team.name).tag(team.id) }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Actions

    private func reset() {
        guard let r = vm.round(roundIndex) else { return }
        teams = r.teams
        matchups = r.matchups
    }

    private func addTeam() {
        let nextLabel = nextTeamLabel()
        let team = Team(id: nextLabel, name: "Team \(nextLabel)", playerIds: ["", ""])
        teams.append(team)
    }

    private func nextTeamLabel() -> String {
        let alphabet = ["A","B","C","D","E","F","G","H"]
        let used = Set(teams.map { $0.id })
        return alphabet.first(where: { !used.contains($0) }) ?? UUID().uuidString.prefix(4).uppercased().description
    }

    private func removeTeam(id: String) {
        teams.removeAll { $0.id == id }
        matchups.removeAll { $0.teamAId == id || $0.teamBId == id }
    }

    private func addMatchup() {
        let used = Set(matchups.flatMap { [$0.teamAId, $0.teamBId] })
        let remaining = teams.filter { !used.contains($0.id) }
        if remaining.count >= 2 {
            matchups.append(Matchup(teamAId: remaining[0].id, teamBId: remaining[1].id))
        } else if let first = teams.first, teams.count >= 2 {
            matchups.append(Matchup(teamAId: first.id, teamBId: teams[1].id))
        }
    }

    private func save() {
        // Drop empty slots before persisting.
        let cleaned = teams.map { team -> Team in
            var t = team
            t.playerIds = t.playerIds.filter { !$0.isEmpty }
            return t
        }
        Task {
            await vm.setTeams(roundIndex: roundIndex, teams: cleaned, matchups: matchups)
        }
    }
}
