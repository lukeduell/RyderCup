import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var ghinHandicap: Double?

    init(id: String = UUID().uuidString, name: String, ghinHandicap: Double? = nil) {
        self.id = id
        self.name = name
        self.ghinHandicap = ghinHandicap
    }
}
