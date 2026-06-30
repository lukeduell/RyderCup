import Foundation

enum SideGameType: String, Codable, CaseIterable {
    case closestToPin     // 1 pt per designated par 3 in R4
    case longDrive        // 1 pt in R4
    case puttingContest   // 2 pts to winner (manual, night before R4)
}

struct SideGameEntry: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var type: SideGameType
    var playerId: String
    var roundIndex: Int?     // optional context
    var holeNumber: Int?     // e.g. specific par-3 for KP
    var points: Double
    var note: String?
}
