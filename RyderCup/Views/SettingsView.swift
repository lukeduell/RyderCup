import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var useGhin: Bool = false
    @State private var birdieBonus: Bool = true
    @State private var showLeaveConfirm: Bool = false

    var body: some View {
        List {
            Section("Tournament") {
                NavigationLink("Players") { PlayersEditView() }
                NavigationLink("Course") { CourseEditView() }
                NavigationLink("Rounds") { RoundsEditView() }
            }
            Section("Scoring") {
                Toggle("Use GHIN handicaps for R4 net play", isOn: $useGhin)
                    .onChange(of: useGhin) { _, v in Task { await vm.setUseGHIN(v) } }
                Toggle("Birdie/eagle bonus points", isOn: $birdieBonus)
                    .onChange(of: birdieBonus) { _, v in Task { await vm.setBirdieEagleEnabled(v) } }
            }
            Section("Sync") {
                HStack {
                    Text("API URL")
                    Spacer()
                    Text(vm.apiBaseURL).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                HStack {
                    Text("Join code")
                    Spacer()
                    Text(vm.tournamentCode).font(.body.monospaced().bold())
                }
                if let last = vm.lastSyncedAt {
                    HStack {
                        Text("Last sync")
                        Spacer()
                        Text(last, style: .relative).foregroundStyle(.secondary)
                    }
                }
                Button("Refresh now") { Task { await vm.refreshOnce() } }
            }
            Section {
                Button("Leave Tournament", role: .destructive) { showLeaveConfirm = true }
                Button("Change API URL") { vm.setBaseURL("") }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            useGhin = vm.tournament?.useGHINHandicaps ?? false
            birdieBonus = vm.tournament?.birdieEagleBonusEnabled ?? true
        }
        .confirmationDialog("Leave this tournament?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { vm.leaveTournament() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can rejoin with the same code anytime. Your scores stay on the server.")
        }
    }
}
