import SwiftUI

struct PlayersEditView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var draft: [Player] = []
    @State private var manualHandicaps: [String: Int] = [:]
    @State private var newName: String = ""
    @State private var newGhin: String = ""

    var body: some View {
        List {
            Section {
                ForEach($draft) { $p in
                    PlayerEditRow(player: $p)
                }
                .onDelete { idx in draft.remove(atOffsets: idx); persistPlayers() }
                .onMove { idx, to in draft.move(fromOffsets: idx, toOffset: to); persistPlayers() }
            } header: {
                HStack {
                    Text("Players (\(draft.count)/8)")
                    Spacer()
                    if draft.count != 8 {
                        Text("Need exactly 8").font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            Section {
                ForEach(draft) { p in
                    HandicapOverrideRow(
                        name: p.name,
                        value: manualHandicaps[p.id]
                    ) { newValue in
                        if let v = newValue { manualHandicaps[p.id] = v }
                        else { manualHandicaps.removeValue(forKey: p.id) }
                        Task { await vm.setHandicapOverride(playerId: p.id, value: newValue) }
                    }
                }
            } header: {
                Text("Manual handicap overrides")
            } footer: {
                Text("When set, this handicap wins over GHIN and over the R1-derived handicap for Saturday-PM net play. Leave blank to use the default.")
            }

            if draft.count < 8 {
                Section("Add player") {
                    TextField("Name", text: $newName)
                    TextField("GHIN handicap (optional)", text: $newGhin)
                        .keyboardType(.decimalPad)
                    Button("Add") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let hcp = Double(newGhin.replacingOccurrences(of: ",", with: "."))
                        draft.append(Player(name: trimmed, ghinHandicap: hcp))
                        newName = ""; newGhin = ""
                        persistPlayers()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("Players")
        .toolbar { EditButton() }
        .onAppear {
            if draft.isEmpty { draft = vm.tournament?.players ?? [] }
            manualHandicaps = vm.tournament?.handicapOverridesMap ?? [:]
        }
        .onChange(of: draft) { _, _ in persistPlayers() }
    }

    private func persistPlayers() {
        Task { await vm.setPlayers(draft) }
    }
}

private struct PlayerEditRow: View {
    @Binding var player: Player
    @State private var hcpString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Name", text: $player.name)
            TextField("GHIN handicap", text: $hcpString)
                .keyboardType(.decimalPad)
                .font(.caption)
                .onChange(of: hcpString) { _, v in
                    player.ghinHandicap = Double(v.replacingOccurrences(of: ",", with: "."))
                }
        }
        .onAppear {
            if let h = player.ghinHandicap { hcpString = String(h) }
        }
    }
}

private struct HandicapOverrideRow: View {
    let name: String
    let value: Int?
    var onCommit: (Int?) -> Void

    @State private var text: String = ""
    @State private var editing: Bool = false

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            TextField("default", text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 90)
                .onAppear { text = value.map(String.init) ?? "" }
                .onChange(of: value) { _, v in if !editing { text = v.map(String.init) ?? "" } }
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
