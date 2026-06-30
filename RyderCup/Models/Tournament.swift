import Foundation

/// Top-level tournament document. Single source of truth synced via Firestore.
struct Tournament: Codable {
    var id: String
    var name: String
    var date: Date
    var players: [Player]
    var course: Course
    var rounds: [Round]
    var scores: [ScoreEntry]              // individual stroke entries (R1, R2, R4)
    var teamScores: [TeamScoreEntry]      // scramble entries (R3)
    var sideGames: [SideGameEntry]
    var useGHINHandicaps: Bool            // R4 handicap source toggle
    var birdieEagleBonusEnabled: Bool

    /// Player id → manual handicap. Wins over GHIN and over the derived-from-R1
    /// handicap when present. Missing keys fall through to the next source.
    var handicapOverrides: [String: Int]? = nil

    var handicapOverridesMap: [String: Int] { handicapOverrides ?? [:] }

    static func empty(id: String = UUID().uuidString) -> Tournament {
        Tournament(
            id: id,
            name: "Ryder Cup Trip",
            date: Date(),
            players: [],
            course: Course.blank(),
            rounds: [
                Round(index: 0, name: "Thursday",      format: .strokePlay),
                Round(index: 1, name: "Friday",        format: .bestBall),
                Round(index: 2, name: "Saturday AM",   format: .scramble),
                Round(index: 3, name: "Saturday PM",   format: .netStrokePlay),
            ],
            scores: [],
            teamScores: [],
            sideGames: [],
            useGHINHandicaps: false,
            birdieEagleBonusEnabled: true,
            handicapOverrides: [:]
        )
    }
}
