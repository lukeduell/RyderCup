import SwiftUI

// MARK: - Stroke Play (R1, R4)

struct StrokePlayScoringView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int
    let isNet: Bool

    @State private var holeNumber: Int = 1
    @State private var editingPlayerId: String?
    @State private var editingStrokes: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            HoleHeader(
                holeNumber: $holeNumber,
                course: vm.tournament?.course
            )
            Divider()
            if let t = vm.tournament {
                List {
                    Section("Hole \(holeNumber) — enter strokes") {
                        ForEach(t.players) { player in
                            PlayerHoleRow(
                                name: player.name,
                                strokes: scoreFor(player: player, hole: holeNumber, scores: t.scores),
                                badge: handicapBadge(player: player, hole: holeNumber)
                            ) { current in
                                editingPlayerId = player.id
                                editingStrokes = current ?? (t.course.hole(holeNumber)?.par ?? 4)
                            } clear: {
                                Task { await vm.clearScore(playerId: player.id, roundIndex: roundIndex, holeNumber: holeNumber) }
                            }
                        }
                    }
                    Section("Totals") {
                        ForEach(t.players) { player in
                            TotalRow(
                                name: player.name,
                                gross: ScoringEngine.grossPartial(playerId: player.id, roundIndex: roundIndex, scores: t.scores),
                                holesPlayed: ScoringEngine.holesCompleted(playerId: player.id, roundIndex: roundIndex, scores: t.scores),
                                net: isNet ? netTotal(player: player) : nil
                            )
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .sheet(item: Binding(
            get: { editingPlayerId.map { EditingTarget(id: $0) } },
            set: { editingPlayerId = $0?.id }
        )) { target in
            NumberPadSheet(
                title: playerName(target.id),
                subtitle: "Hole \(holeNumber) — Par \(vm.tournament?.course.hole(holeNumber)?.par ?? 4)",
                value: $editingStrokes
            ) {
                Task {
                    await vm.setScore(playerId: target.id, roundIndex: roundIndex, holeNumber: holeNumber, strokes: editingStrokes)
                    editingPlayerId = nil
                }
            }
        }
    }

    private struct EditingTarget: Identifiable { let id: String }

    private func scoreFor(player: Player, hole: Int, scores: [ScoreEntry]) -> Int? {
        scores.first(where: { $0.playerId == player.id && $0.roundIndex == roundIndex && $0.holeNumber == hole })?.strokes
    }

    private func netTotal(player: Player) -> Int? {
        guard let t = vm.tournament else { return nil }
        let r1 = t.rounds.first(where: { $0.index == 0 })
        let round = t.rounds.first(where: { $0.index == roundIndex })
        let hcps = ScoringEngine.effectiveHandicaps(
            players: t.players,
            scores: t.scores,
            useGHIN: t.useGHINHandicaps,
            overrides: t.handicapOverridesMap,
            r1Round: r1
        )
        return ScoringEngine.netTotal(playerId: player.id, scores: t.scores, handicaps: hcps, round: round)
    }

    private func handicapBadge(player: Player, hole: Int) -> String? {
        guard isNet, let t = vm.tournament else { return nil }
        let r1 = t.rounds.first(where: { $0.index == 0 })
        let hcps = ScoringEngine.effectiveHandicaps(
            players: t.players,
            scores: t.scores,
            useGHIN: t.useGHINHandicaps,
            overrides: t.handicapOverridesMap,
            r1Round: r1
        )
        guard let hcp = hcps[player.id], hcp > 0 else { return nil }
        let holeIndex = t.course.hole(hole)?.handicapIndex ?? 0
        let strokesGiven = strokesOnHole(handicap: hcp, holeIndex: holeIndex)
        return strokesGiven > 0 ? String(repeating: "•", count: min(strokesGiven, 2)) : nil
    }

    /// Standard handicap allocation: 1 stroke on every hole when HCP=18,
    /// then a second stroke on lowest-index holes when HCP > 18.
    private func strokesOnHole(handicap: Int, holeIndex: Int) -> Int {
        guard handicap > 0, holeIndex > 0 else { return 0 }
        let base = handicap / 18
        let extra = (handicap % 18) >= holeIndex ? 1 : 0
        return base + extra
    }

    private func playerName(_ id: String) -> String {
        vm.tournament?.players.first(where: { $0.id == id })?.name ?? "Player"
    }
}

// MARK: - Best Ball (R2)

struct BestBallScoringView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int

    @State private var holeNumber: Int = 1
    @State private var editingPlayerId: String?
    @State private var editingStrokes: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            HoleHeader(holeNumber: $holeNumber, course: vm.tournament?.course)
            Divider()
            if let t = vm.tournament, let round = vm.round(roundIndex) {
                if round.teams.isEmpty {
                    needsSeeding
                } else {
                    List {
                        ForEach(round.teams) { team in
                            Section(header: bestBallTeamHeader(team: team, players: t.players, scores: t.scores)) {
                                ForEach(team.playerIds, id: \.self) { pid in
                                    if let player = t.players.first(where: { $0.id == pid }) {
                                        PlayerHoleRow(
                                            name: player.name,
                                            strokes: scoreFor(playerId: pid, hole: holeNumber, scores: t.scores),
                                            badge: nil
                                        ) { current in
                                            editingPlayerId = pid
                                            editingStrokes = current ?? (t.course.hole(holeNumber)?.par ?? 4)
                                        } clear: {
                                            Task { await vm.clearScore(playerId: pid, roundIndex: roundIndex, holeNumber: holeNumber) }
                                        }
                                    }
                                }
                                if let bb = ScoringEngine.bestBallHoleScores(team: team, roundIndex: roundIndex, scores: t.scores)[holeNumber] {
                                    HStack {
                                        Text("Team best ball").font(.caption.bold()).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(bb)").font(.callout.bold().monospacedDigit())
                                    }
                                }
                            }
                        }
                        Section("Match totals (18-hole best ball)") {
                            ForEach(round.teams) { team in
                                let total = ScoringEngine.bestBallTotal(team: team, roundIndex: roundIndex, scores: t.scores, round: round)
                                HStack {
                                    Text(team.name).bold()
                                    Spacer()
                                    Text(total.map { "\($0)" } ?? "—").monospacedDigit()
                                }
                            }
                        }
                    }
                }
            } else { ProgressView() }
        }
        .sheet(item: Binding(
            get: { editingPlayerId.map { EditingTarget(id: $0) } },
            set: { editingPlayerId = $0?.id }
        )) { target in
            NumberPadSheet(
                title: playerName(target.id),
                subtitle: "Hole \(holeNumber) — Par \(vm.tournament?.course.hole(holeNumber)?.par ?? 4)",
                value: $editingStrokes
            ) {
                Task {
                    await vm.setScore(playerId: target.id, roundIndex: roundIndex, holeNumber: holeNumber, strokes: editingStrokes)
                    editingPlayerId = nil
                }
            }
        }
    }

    private var needsSeeding: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape").font(.largeTitle).foregroundStyle(.secondary)
            Text("Teams not seeded yet").font(.headline)
            Text("Friday teams come from Thursday's gross totals (1/8, 2/7, 3/6, 4/5).")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Seed from R1") { Task { await vm.autoSeedR2Teams() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private struct EditingTarget: Identifiable { let id: String }

    private func scoreFor(playerId: String, hole: Int, scores: [ScoreEntry]) -> Int? {
        scores.first(where: { $0.playerId == playerId && $0.roundIndex == roundIndex && $0.holeNumber == hole })?.strokes
    }

    @ViewBuilder
    private func bestBallTeamHeader(team: Team, players: [Player], scores: [ScoreEntry]) -> some View {
        let names = team.playerIds.compactMap { id in players.first(where: { $0.id == id })?.name }
        HStack {
            Text(team.name).bold()
            Spacer()
            Text(names.joined(separator: " & ")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func playerName(_ id: String) -> String {
        vm.tournament?.players.first(where: { $0.id == id })?.name ?? "Player"
    }
}

// MARK: - Scramble (R3)

struct ScrambleScoringView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int

    @State private var holeNumber: Int = 1
    @State private var editingTeamId: String?
    @State private var editingStrokes: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            HoleHeader(holeNumber: $holeNumber, course: vm.tournament?.course)
            Divider()
            if let t = vm.tournament, let round = vm.round(roundIndex) {
                if round.teams.isEmpty {
                    needsSeeding
                } else {
                    List {
                        Section("Hole \(holeNumber) — team scramble score") {
                            ForEach(round.teams) { team in
                                let names = team.playerIds.compactMap { id in t.players.first(where: { $0.id == id })?.name }
                                let current = t.teamScores.first(where: { $0.teamId == team.id && $0.roundIndex == roundIndex && $0.holeNumber == holeNumber })?.strokes
                                Button {
                                    editingTeamId = team.id
                                    editingStrokes = current ?? (t.course.hole(holeNumber)?.par ?? 4)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(team.name).bold().foregroundStyle(.primary)
                                            Text(names.joined(separator: " & ")).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(current.map { "\($0)" } ?? "—")
                                            .font(.title3.bold().monospacedDigit())
                                            .frame(width: 44, height: 36)
                                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .swipeActions {
                                    Button("Clear", role: .destructive) {
                                        Task { await vm.clearTeamScore(teamId: team.id, roundIndex: roundIndex, holeNumber: holeNumber) }
                                    }
                                }
                            }
                        }
                        Section("Totals") {
                            ForEach(round.teams) { team in
                                let total = ScoringEngine.scrambleTeamTotal(team: team, roundIndex: roundIndex, teamScores: t.teamScores, round: round)
                                HStack {
                                    Text(team.name).bold()
                                    Spacer()
                                    Text(total.map { "\($0)" } ?? "—").monospacedDigit()
                                }
                            }
                        }
                    }
                }
            } else { ProgressView() }
        }
        .sheet(item: Binding(
            get: { editingTeamId.map { EditingTarget(id: $0) } },
            set: { editingTeamId = $0?.id }
        )) { target in
            NumberPadSheet(
                title: teamName(target.id),
                subtitle: "Hole \(holeNumber) — Par \(vm.tournament?.course.hole(holeNumber)?.par ?? 4)",
                value: $editingStrokes
            ) {
                Task {
                    await vm.setTeamScore(teamId: target.id, roundIndex: roundIndex, holeNumber: holeNumber, strokes: editingStrokes)
                    editingTeamId = nil
                }
            }
        }
    }

    private var needsSeeding: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill").font(.largeTitle).foregroundStyle(.secondary)
            Text("Re-seed for Saturday AM").font(.headline)
            Text("Saturday AM teams re-seed off the standings through Friday.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Re-seed teams") { Task { await vm.autoSeedR3Teams() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private struct EditingTarget: Identifiable { let id: String }

    private func teamName(_ id: String) -> String {
        vm.round(roundIndex)?.teams.first(where: { $0.id == id })?.name ?? "Team"
    }
}

// MARK: - Shared UI atoms

struct HoleHeader: View {
    @Binding var holeNumber: Int
    let course: Course?

    var body: some View {
        let hole = course?.hole(holeNumber)
        HStack {
            Button { holeNumber = max(1, holeNumber - 1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title)
            }
            .disabled(holeNumber <= 1)
            Spacer()
            VStack {
                Text("Hole \(holeNumber)").font(.title2.bold())
                if let h = hole {
                    Text("Par \(h.par) · HCP \(h.handicapIndex)\(h.yardage.map { " · \($0)y" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { holeNumber = min(18, holeNumber + 1) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title)
            }
            .disabled(holeNumber >= 18)
        }
        .padding()
    }
}

struct PlayerHoleRow: View {
    let name: String
    let strokes: Int?
    let badge: String?
    let onTap: (Int?) -> Void
    let clear: () -> Void

    var body: some View {
        Button {
            onTap(strokes)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(strokes.map { "\($0)" } ?? "—")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .swipeActions {
            Button("Clear", role: .destructive) { clear() }
        }
    }
}

struct TotalRow: View {
    let name: String
    let gross: Int
    let holesPlayed: Int
    let net: Int?

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text("\(holesPlayed)/18").font(.caption).foregroundStyle(.secondary)
            Text("\(gross)").font(.body.monospacedDigit().bold()).frame(width: 44)
            if let net {
                Text("net \(net)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}

struct NumberPadSheet: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top)

            Text("\(value)")
                .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(1...9, id: \.self) { n in
                    padButton("\(n)") { value = n }
                }
                padButton("−") { value = max(1, value - 1) }
                padButton("0") { value = max(1, value) /* no-op visually */ }
                padButton("+") { value = min(15, value + 1) }
            }

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
                Button("Save") { onSave(); dismiss() }
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            }
        }
        .padding()
        .presentationDetents([.medium, .large])
    }

    private func padButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.primary)
        }
    }
}
