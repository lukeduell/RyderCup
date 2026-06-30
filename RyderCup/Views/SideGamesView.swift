import SwiftUI

struct SideGamesView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var showAdd: Bool = false

    var body: some View {
        List {
            if let t = vm.tournament {
                Section("Birdies & Eagles (auto)") {
                    if !t.birdieEagleBonusEnabled {
                        Text("Disabled in Settings").foregroundStyle(.secondary)
                    } else {
                        let totals = ScoringEngine.birdieEaglePoints(scores: t.scores, course: t.course)
                        let players = t.players.sorted { (totals[$0.id] ?? 0) > (totals[$1.id] ?? 0) }
                        ForEach(players) { p in
                            HStack {
                                Text(p.name)
                                Spacer()
                                let pts = totals[p.id] ?? 0
                                if pts > 0 {
                                    Text("+\(format(pts)) pts").font(.body.monospacedDigit().bold())
                                } else {
                                    Text("—").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Manual entries") {
                    ForEach(t.sideGames) { entry in
                        let player = t.players.first(where: { $0.id == entry.playerId })
                        HStack {
                            VStack(alignment: .leading) {
                                Text(player?.name ?? "?").bold()
                                Text(label(entry)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(format(entry.points))").font(.body.monospacedDigit().bold())
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { await vm.removeSideGame(entry.id) }
                            }
                        }
                    }
                    if t.sideGames.isEmpty { Text("Nothing yet").foregroundStyle(.secondary) }
                }
                Section {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add side-game entry", systemImage: "plus.circle.fill")
                    }
                } footer: {
                    Text("Use for closest-to-pin on par-3s, long drive winner, and the putting-contest result.")
                }
            }
        }
        .navigationTitle("Side Games")
        .sheet(isPresented: $showAdd) {
            AddSideGameSheet()
                .environmentObject(vm)
        }
    }

    private func label(_ entry: SideGameEntry) -> String {
        var bits: [String] = []
        bits.append(entry.type.label)
        if let h = entry.holeNumber { bits.append("Hole \(h)") }
        if let note = entry.note, !note.isEmpty { bits.append(note) }
        return bits.joined(separator: " · ")
    }

    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

extension SideGameType {
    var label: String {
        switch self {
        case .closestToPin: return "Closest to Pin"
        case .longDrive: return "Long Drive"
        case .puttingContest: return "Putting Contest"
        }
    }
}

private struct AddSideGameSheet: View {
    @EnvironmentObject var vm: TournamentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var type: SideGameType = .closestToPin
    @State private var playerId: String?
    @State private var holeNumber: Int = 0
    @State private var pointsString: String = "1"
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    Text(SideGameType.closestToPin.label).tag(SideGameType.closestToPin)
                    Text(SideGameType.longDrive.label).tag(SideGameType.longDrive)
                    Text(SideGameType.puttingContest.label).tag(SideGameType.puttingContest)
                }
                .onChange(of: type) { _, t in
                    pointsString = t == .puttingContest ? "2" : "1"
                }
                Picker("Player", selection: $playerId) {
                    Text("Pick…").tag(String?.none)
                    ForEach(vm.tournament?.players ?? []) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }
                if type == .closestToPin {
                    Stepper("Hole \(holeNumber == 0 ? "—" : "\(holeNumber)")", value: $holeNumber, in: 0...18)
                }
                TextField("Points", text: $pointsString)
                    .keyboardType(.decimalPad)
                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(playerId == nil || Double(pointsString) == nil)
                }
            }
        }
    }

    private func save() {
        guard let playerId, let points = Double(pointsString) else { return }
        let entry = SideGameEntry(
            type: type,
            playerId: playerId,
            roundIndex: type == .puttingContest ? nil : 3,
            holeNumber: type == .closestToPin ? holeNumber : nil,
            points: points,
            note: note.isEmpty ? nil : note
        )
        Task { await vm.addSideGame(entry); dismiss() }
    }
}
