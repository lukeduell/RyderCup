import Foundation

enum RoundFormat: String, Codable, CaseIterable, Identifiable {
    case strokePlay        // R1: Thursday individual gross
    case bestBall          // R2: Friday 2-man best ball, head-to-head
    case scramble          // R3: Saturday AM 2-man scramble
    case netStrokePlay     // R4: Saturday PM individual net

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strokePlay: return "Individual Stroke Play"
        case .bestBall: return "2-Man Best Ball"
        case .scramble: return "2-Man Scramble"
        case .netStrokePlay: return "Net Stroke Play"
        }
    }

    var shortName: String {
        switch self {
        case .strokePlay: return "Stroke"
        case .bestBall: return "Best Ball"
        case .scramble: return "Scramble"
        case .netStrokePlay: return "Net Stroke"
        }
    }
}

enum RoundStatus: String, Codable {
    case notStarted, inProgress, completed
}

struct Round: Identifiable, Codable, Hashable {
    var index: Int            // 0..3
    var name: String          // "Thursday", "Friday", "Saturday AM", "Saturday PM"
    var format: RoundFormat
    var status: RoundStatus = .notStarted
    var teams: [Team] = []    // populated for bestBall + scramble
    var matchups: [Matchup] = []  // populated for bestBall

    // ---- Manual overrides. When present, the scoring engine prefers these
    // values over the ones computed from hole-by-hole entries. Per-player /
    // per-team. Leave entries out (or set keys absent) to fall back to
    // computed values.

    /// Player id → final round points. Replaces computed.
    var pointsOverride: [String: Double]? = nil

    /// Player id → 18-hole gross total. Used in place of summed hole scores
    /// for stroke / best-ball / net rounds when an entry is present.
    var grossOverride: [String: Int]? = nil

    /// Team id → 18-hole scramble total. Used in place of summed team scores
    /// for scramble rounds when an entry is present.
    var teamScoreOverride: [String: Int]? = nil

    var id: Int { index }

    var pointsOverrideMap: [String: Double] { pointsOverride ?? [:] }
    var grossOverrideMap: [String: Int] { grossOverride ?? [:] }
    var teamScoreOverrideMap: [String: Int] { teamScoreOverride ?? [:] }
}

struct Matchup: Codable, Hashable, Identifiable {
    var id: String { "\(teamAId)-vs-\(teamBId)" }
    var teamAId: String
    var teamBId: String
}
