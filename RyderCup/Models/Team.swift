import Foundation

struct Team: Identifiable, Codable, Hashable {
    var id: String        // "A", "B", "C", "D"
    var name: String      // "Team A"
    var playerIds: [String]
    var seedLabel: String? // e.g. "1/8", "2/7"

    init(id: String, name: String, playerIds: [String], seedLabel: String? = nil) {
        self.id = id
        self.name = name
        self.playerIds = playerIds
        self.seedLabel = seedLabel
    }
}
