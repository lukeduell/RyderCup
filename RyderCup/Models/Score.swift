import Foundation

/// Individual stroke entry for a (player, round, hole) tuple.
/// Used for stroke play, best ball, and net stroke play (each player has own ball).
struct ScoreEntry: Identifiable, Codable, Hashable {
    var playerId: String
    var roundIndex: Int
    var holeNumber: Int
    var strokes: Int

    var id: String { Self.makeId(playerId: playerId, roundIndex: roundIndex, holeNumber: holeNumber) }

    static func makeId(playerId: String, roundIndex: Int, holeNumber: Int) -> String {
        "\(playerId)_r\(roundIndex)_h\(holeNumber)"
    }
}

/// Single team-strokes entry for scramble rounds (one ball, one score per team per hole).
struct TeamScoreEntry: Identifiable, Codable, Hashable {
    var teamId: String
    var roundIndex: Int
    var holeNumber: Int
    var strokes: Int

    var id: String { "\(teamId)_r\(roundIndex)_h\(holeNumber)" }
}
