import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var vm: TournamentViewModel

    var body: some View {
        List {
            if let t = vm.tournament {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(t.name).font(.headline)
                            Text("Code: \(t.id.prefix(0))\(vm.tournamentCode)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        connectionPill
                    }
                }
                Section("Standings") {
                    let board = vm.leaderboard()
                    ForEach(Array(board.enumerated()), id: \.element.id) { idx, card in
                        LeaderboardRow(position: idx + 1, card: card)
                    }
                }
            } else {
                Text("Loading…")
            }
        }
        .navigationTitle("Leaderboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.refreshOnce() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    @ViewBuilder
    private var connectionPill: some View {
        let (label, color): (String, Color) = {
            switch vm.connectionState {
            case .connected: return ("Live", .green)
            case .connecting: return ("Sync…", .yellow)
            case .disconnected: return ("Offline", .red)
            }
        }()
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct LeaderboardRow: View {
    let position: Int
    let card: ScoringEngine.PlayerScorecard

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.title3.bold())
                .frame(width: 28)
                .foregroundStyle(position <= 3 ? .yellow : .primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.player.name).font(.body.bold())
                HStack(spacing: 6) {
                    RoundPip(label: "T", value: card.roundPoints[0] ?? 0)
                    RoundPip(label: "F", value: card.roundPoints[1] ?? 0)
                    RoundPip(label: "SA", value: card.roundPoints[2] ?? 0)
                    RoundPip(label: "SP", value: card.roundPoints[3] ?? 0)
                    if card.birdieEaglePoints > 0 {
                        RoundPip(label: "BE", value: card.birdieEaglePoints)
                    }
                    if card.sideGamePoints > 0 {
                        RoundPip(label: "+", value: card.sideGamePoints)
                    }
                }
            }
            Spacer()
            Text(formatPoints(card.total))
                .font(.title3.bold().monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    private func formatPoints(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

private struct RoundPip: View {
    let label: String
    let value: Double

    var body: some View {
        Text("\(label) \(format(value))")
            .font(.caption2.monospaced())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.gray.opacity(0.18), in: Capsule())
    }

    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
