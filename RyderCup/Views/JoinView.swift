import SwiftUI

struct JoinView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var code: String = ""
    @State private var newTournamentName: String = "Ryder Cup Trip"
    @State private var isCreating = false
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Ryder Cup")
                    .font(.largeTitle.bold())
                Text(vm.apiBaseURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    TextField("Join Code (e.g. K3F9XB)", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        isJoining = true
                        Task { await vm.joinTournament(code: code); isJoining = false }
                    } label: {
                        if isJoining { ProgressView() } else { Text("Join Tournament").bold() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || isJoining)
                }
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 60)

                VStack(spacing: 12) {
                    TextField("Tournament name", text: $newTournamentName)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        isCreating = true
                        Task { await vm.createTournament(name: newTournamentName); isCreating = false }
                    } label: {
                        if isCreating { ProgressView() } else { Text("Create New") }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isCreating)
                }
                .padding(.horizontal, 24)

                if let err = vm.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
                Button("Change API URL") { vm.setBaseURL("") }
                    .font(.caption)
            }
            .navigationBarHidden(true)
        }
    }
}
