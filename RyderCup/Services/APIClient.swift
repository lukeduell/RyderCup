import Foundation

/// REST client for the RyderCup ASP.NET Core backend.
///
/// All endpoints are scoped under `/api/tournaments/{code}`. The shared tournament
/// `code` is the only credential — anyone with the code can read/write the tournament,
/// which is fine for a private 8-person trip.
final class APIClient {

    enum APIError: Error, LocalizedError {
        case invalidURL
        case server(Int, String)
        case decoding(Error)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid base URL — check Settings"
            case .server(let code, let msg): return "Server \(code): \(msg)"
            case .decoding(let e): return "Decode failed: \(e.localizedDescription)"
            case .transport(let e): return "Network: \(e.localizedDescription)"
            }
        }
    }

    let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCaseLowerCamel
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder.dateDecodingStrategy = .iso8601WithFractional
    }

    // MARK: - Tournaments

    func createTournament(name: String) async throws -> TournamentSnapshot {
        try await send(method: "POST", path: "/api/tournaments", body: ["name": name])
    }

    func fetchTournament(code: String) async throws -> TournamentSnapshot {
        try await send(method: "GET", path: "/api/tournaments/\(code)")
    }

    @discardableResult
    func updateMeta(code: String, request: MetaUpdate) async throws -> TournamentSnapshot {
        try await send(method: "PATCH", path: "/api/tournaments/\(code)", body: request)
    }

    // MARK: - Scores

    func upsertScore(code: String, entry: ScoreEntry) async throws {
        try await sendNoContent(
            method: "POST",
            path: "/api/tournaments/\(code)/scores",
            body: ScoreUpsert(playerId: entry.playerId, roundIndex: entry.roundIndex, holeNumber: entry.holeNumber, strokes: entry.strokes)
        )
    }

    func deleteScore(code: String, playerId: String, roundIndex: Int, holeNumber: Int) async throws {
        try await sendNoContent(
            method: "DELETE",
            path: "/api/tournaments/\(code)/scores/\(playerId)/\(roundIndex)/\(holeNumber)",
            body: Optional<EmptyBody>.none
        )
    }

    func upsertTeamScore(code: String, entry: TeamScoreEntry) async throws {
        try await sendNoContent(
            method: "POST",
            path: "/api/tournaments/\(code)/team-scores",
            body: TeamScoreUpsert(teamId: entry.teamId, roundIndex: entry.roundIndex, holeNumber: entry.holeNumber, strokes: entry.strokes)
        )
    }

    func deleteTeamScore(code: String, teamId: String, roundIndex: Int, holeNumber: Int) async throws {
        try await sendNoContent(
            method: "DELETE",
            path: "/api/tournaments/\(code)/team-scores/\(teamId)/\(roundIndex)/\(holeNumber)",
            body: Optional<EmptyBody>.none
        )
    }

    // MARK: - Side games

    func upsertSideGame(code: String, entry: SideGameEntry) async throws {
        try await sendNoContent(
            method: "POST",
            path: "/api/tournaments/\(code)/side-games",
            body: SideGameUpsert(
                id: entry.id,
                type: entry.type.rawValue,
                playerId: entry.playerId,
                roundIndex: entry.roundIndex,
                holeNumber: entry.holeNumber,
                points: entry.points,
                note: entry.note
            )
        )
    }

    func deleteSideGame(code: String, id: String) async throws {
        try await sendNoContent(
            method: "DELETE",
            path: "/api/tournaments/\(code)/side-games/\(id)",
            body: Optional<EmptyBody>.none
        )
    }

    // MARK: - Plumbing

    private struct EmptyBody: Encodable {}

    private func send<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        let data = try await sendRaw(method: method, path: path, body: body)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func sendNoContent(method: String, path: String, body: Encodable?) async throws {
        _ = try await sendRaw(method: method, path: path, body: body)
    }

    private func sendRaw(method: String, path: String, body: Encodable?) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do { req.httpBody = try encoder.encode(AnyEncodable(body)) }
            catch { throw APIError.decoding(error) }
        }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.server(0, "No HTTP response")
            }
            if !(200..<300).contains(http.statusCode) {
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw APIError.server(http.statusCode, msg)
            }
            return data
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }
}

// Wraps an Encodable so a heterogeneous payload can be encoded behind a Codable boundary.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

extension JSONDecoder.DateDecodingStrategy {
    /// Tolerates both `2026-07-08T12:34:56Z` and `...56.789Z` from ASP.NET.
    static var iso8601WithFractional: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }(),
            ]
            for f in formatters {
                if let d = f.date(from: s) { return d }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(s)")
        }
    }
}

extension JSONEncoder.KeyEncodingStrategy {
    /// ASP.NET's default `JsonNamingPolicy.CamelCase` matches Swift's camelCase,
    /// so this is effectively a passthrough — kept as a hook in case the server
    /// changes naming.
    static var convertToSnakeCaseLowerCamel: JSONEncoder.KeyEncodingStrategy {
        .useDefaultKeys
    }
}

// MARK: - Wire types matching the C# DTOs

struct TournamentSnapshot: Codable {
    let id: String
    let code: String
    let name: String
    let date: Date
    let players: [Player]
    let course: Course
    let rounds: [Round]
    let useGhinHandicaps: Bool
    let birdieEagleBonusEnabled: Bool
    let handicapOverrides: [String: Int]?
    let scores: [ScoreEntry]
    let teamScores: [TeamScoreEntry]
    let sideGames: [SideGameEntry]
    let updatedAt: Date

    func toTournament() -> Tournament {
        Tournament(
            id: id,
            name: name,
            date: date,
            players: players,
            course: course,
            rounds: rounds,
            scores: scores,
            teamScores: teamScores,
            sideGames: sideGames,
            useGHINHandicaps: useGhinHandicaps,
            birdieEagleBonusEnabled: birdieEagleBonusEnabled,
            handicapOverrides: handicapOverrides ?? [:]
        )
    }
}

struct MetaUpdate: Codable {
    var name: String?
    var date: Date?
    var players: [Player]?
    var course: Course?
    var rounds: [Round]?
    var useGhinHandicaps: Bool?
    var birdieEagleBonusEnabled: Bool?
    var handicapOverrides: [String: Int]?
}

private struct ScoreUpsert: Codable {
    let playerId: String
    let roundIndex: Int
    let holeNumber: Int
    let strokes: Int
}

private struct TeamScoreUpsert: Codable {
    let teamId: String
    let roundIndex: Int
    let holeNumber: Int
    let strokes: Int
}

private struct SideGameUpsert: Codable {
    let id: String
    let type: String
    let playerId: String
    let roundIndex: Int?
    let holeNumber: Int?
    let points: Double
    let note: String?
}
