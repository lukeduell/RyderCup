import Foundation

struct Hole: Identifiable, Codable, Hashable {
    var number: Int
    var par: Int
    var handicapIndex: Int
    var yardage: Int?

    var id: Int { number }
}

struct Course: Codable, Hashable {
    var name: String
    var holes: [Hole]

    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }

    static func blank(name: String = "Course TBD") -> Course {
        let holes = (1...18).map { n -> Hole in
            let defaultPar = (n == 3 || n == 7 || n == 12 || n == 16) ? 3
                : (n == 5 || n == 14) ? 5
                : 4
            return Hole(number: n, par: defaultPar, handicapIndex: n)
        }
        return Course(name: name, holes: holes)
    }

    func hole(_ number: Int) -> Hole? {
        holes.first(where: { $0.number == number })
    }
}
