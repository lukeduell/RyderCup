import SwiftUI

struct RoundsEditView: View {
    @EnvironmentObject var vm: TournamentViewModel

    var body: some View {
        List {
            if let t = vm.tournament {
                ForEach(t.rounds) { round in
                    NavigationLink {
                        SingleRoundEditView(roundIndex: round.index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(round.name).font(.headline)
                                Text(round.format.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusPill(round.status)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rounds")
    }

    @ViewBuilder
    private func statusPill(_ status: RoundStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .notStarted: return ("Not started", .secondary)
            case .inProgress: return ("In progress", .yellow)
            case .completed: return ("Complete", .green)
            }
        }()
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct SingleRoundEditView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int

    @State private var name: String = ""
    @State private var status: RoundStatus = .notStarted
    @State private var format: RoundFormat = .strokePlay

    var body: some View {
        Form {
            if let round = vm.round(roundIndex), let t = vm.tournament {
                Section("Round info") {
                    TextField("Name", text: $name)
                    Picker("Format", selection: $format) {
                        ForEach(RoundFormat.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    Picker("Status", selection: $status) {
                        Text("Not started").tag(RoundStatus.notStarted)
                        Text("In progress").tag(RoundStatus.inProgress)
                        Text("Completed").tag(RoundStatus.completed)
                    }
                }

                if format == .bestBall || format == .scramble {
                    Section("Teams") {
                        NavigationLink {
                            TeamEditView(roundIndex: roundIndex)
                        } label: {
                            Label(round.teams.isEmpty ? "Set up teams" : "Edit teams (\(round.teams.count))",
                                  systemImage: "person.2.fill")
                        }
                        Button {
                            Task {
                                if format == .bestBall { await vm.autoSeedR2Teams() }
                                else { await vm.autoSeedR3Teams() }
                            }
                        } label: {
                            Label("Auto-seed from standings", systemImage: "wand.and.stars")
                        }
                    }
                }

                grossOverrideSection(round: round, t: t)

                if format == .scramble {
                    teamScoreOverrideSection(round: round, t: t)
                }

                pointsOverrideSection(round: round, t: t)

                Section { Button("Save round info") { save() } }
            }
        }
        .navigationTitle(vm.round(roundIndex)?.name ?? "Round")
        .onAppear { reset() }
    }

    private func reset() {
        guard let r = vm.round(roundIndex) else { return }
        name = r.name
        status = r.status
        format = r.format
    }

    private func save() {
        guard var r = vm.round(roundIndex) else { return }
        r.name = name
        r.status = status
        r.format = format
        Task { await vm.updateRound(r) }
    }

    // MARK: - Override sections

    @ViewBuilder
    private func grossOverrideSection(round: Round, t: Tournament) -> some View {
        Section {
            ForEach(t.players) { p in
                OverrideIntRow(
                    label: p.name,
                    placeholder: "computed",
                    value: round.grossOverrideMap[p.id]
                ) { newValue in
                    Task { await vm.setGrossOverride(roundIndex: roundIndex, playerId: p.id, gross: newValue) }
                }
            }
        } header: {
            Text("Gross overrides")
        } footer: {
            Text("Type an 18-hole gross total to skip hole-by-hole entry for a player. Leave blank to use the summed hole scores.")
        }
    }

    @ViewBuilder
    private func teamScoreOverrideSection(round: Round, t: Tournament) -> some View {
        Section {
            ForEach(round.teams) { team in
                OverrideIntRow(
                    label: team.name,
                    placeholder: "computed",
                    value: round.teamScoreOverrideMap[team.id]
                ) { newValue in
                    Task { await vm.setTeamScoreOverride(roundIndex: roundIndex, teamId: team.id, total: newValue) }
                }
            }
        } header: {
            Text("Team score overrides")
        } footer: {
            Text("Type a 18-hole scramble total to override the per-hole sum.")
        }
    }

    @ViewBuilder
    private func pointsOverrideSection(round: Round, t: Tournament) -> some View {
        Section {
            ForEach(t.players) { p in
                OverrideDoubleRow(
                    label: p.name,
                    placeholder: "computed",
                    value: round.pointsOverrideMap[p.id]
                ) { newValue in
                    Task { await vm.setPointsOverride(roundIndex: roundIndex, playerId: p.id, points: newValue) }
                }
            }
        } header: {
            Text("Points overrides")
        } footer: {
            Text("Type a final point total for a player to override what the engine would compute. Used to correct disputed results or hand-adjust a round.")
        }
    }
}

// MARK: - Override input rows

private struct OverrideIntRow: View {
    let label: String
    let placeholder: String
    let value: Int?
    var onCommit: (Int?) -> Void

    @State private var text: String = ""
    @State private var editing: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 100)
                .onAppear { text = value.map(String.init) ?? "" }
                .onChange(of: value) { _, v in
                    if !editing { text = v.map(String.init) ?? "" }
                }
                .onSubmit { commit() }
                .onTapGesture { editing = true }
            Button {
                text = ""
                onCommit(nil)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(value == nil ? 0 : 1)
        }
        .swipeActions {
            Button("Save") { commit() }.tint(.blue)
        }
    }

    private func commit() {
        editing = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { onCommit(nil); return }
        if let v = Int(trimmed) { onCommit(v) }
    }
}

private struct OverrideDoubleRow: View {
    let label: String
    let placeholder: String
    let value: Double?
    var onCommit: (Double?) -> Void

    @State private var text: String = ""
    @State private var editing: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 100)
                .onAppear { text = formatted(value) }
                .onChange(of: value) { _, v in
                    if !editing { text = formatted(v) }
                }
                .onSubmit { commit() }
                .onTapGesture { editing = true }
            Button {
                text = ""
                onCommit(nil)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(value == nil ? 0 : 1)
        }
        .swipeActions {
            Button("Save") { commit() }.tint(.blue)
        }
    }

    private func formatted(_ v: Double?) -> String {
        guard let v else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func commit() {
        editing = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { onCommit(nil); return }
        if let v = Double(trimmed) { onCommit(v) }
    }
}
