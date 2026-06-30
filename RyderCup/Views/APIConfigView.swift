import SwiftUI

struct APIConfigView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var url: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("API Base URL") {
                    TextField("https://your-app.railway.app", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    Button("Continue") {
                        vm.setBaseURL(url)
                    }
                    .disabled(!isValid)
                } footer: {
                    Text("Where your RyderCup backend lives. The trip host shares this URL with everyone. Saved on this device.")
                }
            }
            .navigationTitle("Setup")
        }
        .onAppear { if url.isEmpty { url = vm.apiBaseURL } }
    }

    private var isValid: Bool {
        URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.hasPrefix("http") == true
    }
}
