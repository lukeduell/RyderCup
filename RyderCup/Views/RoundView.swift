import SwiftUI

struct RoundView: View {
    @EnvironmentObject var vm: TournamentViewModel
    let roundIndex: Int
    @State private var localActiveRound: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            roundPicker
            Divider()
            content
        }
        .navigationTitle("Round")
        .onAppear { localActiveRound = vm.activeRoundIndex }
    }

    private var roundPicker: some View {
        Picker("Round", selection: Binding(
            get: { vm.activeRoundIndex },
            set: { vm.activeRoundIndex = $0; localActiveRound = $0 }
        )) {
            Text("Thu (R1)").tag(0)
            Text("Fri (R2)").tag(1)
            Text("Sat AM (R3)").tag(2)
            Text("Sat PM (R4)").tag(3)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if let round = vm.round(vm.activeRoundIndex) {
            switch round.format {
            case .strokePlay:    StrokePlayScoringView(roundIndex: round.index, isNet: false)
            case .netStrokePlay: StrokePlayScoringView(roundIndex: round.index, isNet: true)
            case .bestBall:      BestBallScoringView(roundIndex: round.index)
            case .scramble:      ScrambleScoringView(roundIndex: round.index)
            }
        } else {
            Text("Round not configured")
        }
    }
}
