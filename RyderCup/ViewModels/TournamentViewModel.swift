import Foundation
import SwiftUI
import Combine

/// Central state container. Owns:
///   - tournament snapshot loaded from the backend
///   - polling timer that refreshes that snapshot every 4s
///   - write methods that POST to the backend and optimistically update local state
///
/// Views observe this object via `@EnvironmentObject`.
@MainActor
final class TournamentViewModel: ObservableObject {

    // MARK: - Published state

    @Published var tournament: Tournament?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    @Published var lastSyncedAt: Date?

    enum ConnectionState {
        case disconnected, connecting, connected
    }

    // MARK: - Config (persisted in UserDefaults)

    @AppStorage("apiBaseURL") private var storedBaseURL: String = ""
    @AppStorage("tournamentCode") private var storedCode: String = ""
    @AppStorage("activeRoundIndex") private var storedActiveRound: Int = 0

    var apiBaseURL: String {
        get { storedBaseURL }
        set { storedBaseURL = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var tournamentCode: String {
        get { storedCode }
        set { storedCode = newValue.uppercased() }
    }

    var activeRoundIndex: Int {
        get { storedActiveRound }
        set { storedActiveRound = max(0, min(3, newValue)) }
    }

    // MARK: - Internals

    private var client: APIClient?
    private var pollTask: Task<Void, Never>?

    init() {
        // Seed the base URL from build config on first launch (Debug → localhost,
        // Release → Railway). The user can still override in Settings.
        if storedBaseURL.isEmpty {
            storedBaseURL = AppConfig.defaultAPIBaseURL
        }
        rebuildClient()
    }

    private func rebuildClient() {
        if let url = URL(string: storedBaseURL), !storedBaseURL.isEmpty {
            client = APIClient(baseURL: url)
        } else {
            client = nil
        }
    }

    // MARK: - Lifecycle

    func start() {
        rebuildClient()
        guard client != nil, !tournamentCode.isEmpty else { return }
        Task { await refreshOnce() }
        startPolling()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self else { return }
                await self.refreshOnce()
            }
        }
    }

    // MARK: - Joining / Creating

    func setBaseURL(_ url: String) {
        apiBaseURL = url
        rebuildClient()
    }

    func createTournament(name: String) async {
        guard let client else { lastError = "No API URL"; return }
        connectionState = .connecting
        do {
            let snap = try await client.createTournament(name: name)
            tournamentCode = snap.code
            apply(snap)
            connectionState = .connected
            startPolling()
        } catch {
            lastError = (error as? APIClient.APIError)?.localizedDescription ?? error.localizedDescription
            connectionState = .disconnected
        }
    }

    func joinTournament(code: String) async {
        guard let client else { lastError = "No API URL"; return }
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        connectionState = .connecting
        do {
            let snap = try await client.fetchTournament(code: normalized)
            tournamentCode = normalized
            apply(snap)
            connectionState = .connected
            startPolling()
        } catch {
            lastError = (error as? APIClient.APIError)?.localizedDescription ?? error.localizedDescription
            connectionState = .disconnected
        }
    }

    func leaveTournament() {
        stop()
        tournament = nil
        tournamentCode = ""
        connectionState = .disconnected
    }

    // MARK: - Refresh

    func refreshOnce() async {
        guard let client, !tournamentCode.isEmpty else { return }
        do {
            let snap = try await client.fetchTournament(code: tournamentCode)
            apply(snap)
            connectionState = .connected
            lastSyncedAt = Date()
        } catch {
            connectionState = .disconnected
            lastError = (error as? APIClient.APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func apply(_ snap: TournamentSnapshot) {
        let next = snap.toTournament()
        if tournament == nil || (tournament?.id == next.id) {
            tournament = next
        } else {
            tournament = next
        }
    }

    // MARK: - Meta updates

    func updateMeta(_ patch: MetaUpdate) async {
        guard let client, !tournamentCode.isEmpty else { return }
        do {
            let snap = try await client.updateMeta(code: tournamentCode, request: patch)
            apply(snap)
        } catch {
            lastError = (error as? APIClient.APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func setPlayers(_ players: [Player]) async {
        await updateMeta(MetaUpdate(players: players))
    }

    func setCourse(_ course: Course) async {
        await updateMeta(MetaUpdate(course: course))
    }

    func setRounds(_ rounds: [Round]) async {
        await updateMeta(MetaUpdate(rounds: rounds))
    }

    func setUseGHIN(_ value: Bool) async {
        await updateMeta(MetaUpdate(useGhinHandicaps: value))
    }

    func setBirdieEagleEnabled(_ value: Bool) async {
        await updateMeta(MetaUpdate(birdieEagleBonusEnabled: value))
    }

    // MARK: - Override writes

    /// Replaces the entire handicap-override map. Pass [:] to clear.
    func setHandicapOverrides(_ map: [String: Int]) async {
        await updateMeta(MetaUpdate(handicapOverrides: map))
    }

    /// Sets a single player's manual handicap. Pass nil to clear that one entry.
    func setHandicapOverride(playerId: String, value: Int?) async {
        guard let t = tournament else { return }
        var map = t.handicapOverridesMap
        if let v = value { map[playerId] = v } else { map.removeValue(forKey: playerId) }
        await setHandicapOverrides(map)
    }

    /// Updates a single round (format, teams, matchups, overrides) and pushes it
    /// to the backend in one PATCH.
    func updateRound(_ round: Round) async {
        guard var t = tournament else { return }
        guard let i = t.rounds.firstIndex(where: { $0.index == round.index }) else { return }
        t.rounds[i] = round
        await setRounds(t.rounds)
    }

    /// Sets the format for a given round.
    func setRoundFormat(_ roundIndex: Int, _ format: RoundFormat) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        round.format = format
        await updateRound(round)
    }

    /// Sets a player's points override for a round. Pass nil to clear.
    func setPointsOverride(roundIndex: Int, playerId: String, points: Double?) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        var map = round.pointsOverrideMap
        if let p = points { map[playerId] = p } else { map.removeValue(forKey: playerId) }
        round.pointsOverride = map
        await updateRound(round)
    }

    /// Sets a player's 18-hole gross override for a round. Pass nil to clear.
    func setGrossOverride(roundIndex: Int, playerId: String, gross: Int?) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        var map = round.grossOverrideMap
        if let g = gross { map[playerId] = g } else { map.removeValue(forKey: playerId) }
        round.grossOverride = map
        await updateRound(round)
    }

    /// Sets a team's scramble total override. Pass nil to clear.
    func setTeamScoreOverride(roundIndex: Int, teamId: String, total: Int?) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        var map = round.teamScoreOverrideMap
        if let v = total { map[teamId] = v } else { map.removeValue(forKey: teamId) }
        round.teamScoreOverride = map
        await updateRound(round)
    }

    /// Replaces team membership for a round (manual override of auto-seed).
    func setTeams(roundIndex: Int, teams: [Team], matchups: [Matchup]? = nil) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        round.teams = teams
        if let m = matchups { round.matchups = m }
        await updateRound(round)
    }

    func setMatchups(roundIndex: Int, matchups: [Matchup]) async {
        guard let t = tournament,
              var round = t.rounds.first(where: { $0.index == roundIndex }) else { return }
        round.matchups = matchups
        await updateRound(round)
    }

    // MARK: - Score writes (optimistic + remote)

    func setScore(playerId: String, roundIndex: Int, holeNumber: Int, strokes: Int) async {
        guard let client, !tournamentCode.isEmpty else { return }
        let entry = ScoreEntry(playerId: playerId, roundIndex: roundIndex, holeNumber: holeNumber, strokes: strokes)
        applyLocalScore(entry)
        do { try await client.upsertScore(code: tournamentCode, entry: entry) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    func clearScore(playerId: String, roundIndex: Int, holeNumber: Int) async {
        guard let client, !tournamentCode.isEmpty else { return }
        let id = ScoreEntry.makeId(playerId: playerId, roundIndex: roundIndex, holeNumber: holeNumber)
        if var t = tournament { t.scores.removeAll { $0.id == id }; tournament = t }
        do { try await client.deleteScore(code: tournamentCode, playerId: playerId, roundIndex: roundIndex, holeNumber: holeNumber) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    func setTeamScore(teamId: String, roundIndex: Int, holeNumber: Int, strokes: Int) async {
        guard let client, !tournamentCode.isEmpty else { return }
        let entry = TeamScoreEntry(teamId: teamId, roundIndex: roundIndex, holeNumber: holeNumber, strokes: strokes)
        applyLocalTeamScore(entry)
        do { try await client.upsertTeamScore(code: tournamentCode, entry: entry) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    func clearTeamScore(teamId: String, roundIndex: Int, holeNumber: Int) async {
        guard let client, !tournamentCode.isEmpty else { return }
        let id = "\(teamId)_r\(roundIndex)_h\(holeNumber)"
        if var t = tournament { t.teamScores.removeAll { $0.id == id }; tournament = t }
        do { try await client.deleteTeamScore(code: tournamentCode, teamId: teamId, roundIndex: roundIndex, holeNumber: holeNumber) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    func addSideGame(_ entry: SideGameEntry) async {
        guard let client, !tournamentCode.isEmpty else { return }
        if var t = tournament {
            t.sideGames.removeAll { $0.id == entry.id }
            t.sideGames.append(entry)
            tournament = t
        }
        do { try await client.upsertSideGame(code: tournamentCode, entry: entry) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    func removeSideGame(_ id: String) async {
        guard let client, !tournamentCode.isEmpty else { return }
        if var t = tournament { t.sideGames.removeAll { $0.id == id }; tournament = t }
        do { try await client.deleteSideGame(code: tournamentCode, id: id) }
        catch { lastError = error.localizedDescription; await refreshOnce() }
    }

    // MARK: - Tournament workflow helpers

    /// Generates teams from R1 results and writes them back as the R2 rounds.teams + matchups.
    func autoSeedR2Teams() async {
        guard var t = tournament else { return }
        let rankings = ScoringEngine.rankPlayersGross(players: t.players, scores: t.scores, roundIndex: 0)
        guard rankings.count == 8 else { lastError = "R1 must be complete (all 18 holes, all 8 players) before seeding R2"; return }
        let teams = ScoringEngine.autoPairTeams(rankings: rankings)
        let matchups = ScoringEngine.defaultBestBallMatchups(teams: teams)
        if let i = t.rounds.firstIndex(where: { $0.index == 1 }) {
            t.rounds[i].teams = teams
            t.rounds[i].matchups = matchups
        }
        await setRounds(t.rounds)
    }

    /// Re-seeds R3 teams from cumulative points through R2.
    func autoSeedR3Teams() async {
        guard var t = tournament else { return }
        let board = ScoringEngine.leaderboard(t)
        guard board.count == 8 else { lastError = "Need all 8 players to seed R3"; return }
        // Convert leaderboard order into pseudo-rankings (1..8) for autoPairTeams.
        let rankings: [ScoringEngine.PlayerRanking] = board.enumerated().map { idx, card in
            ScoringEngine.PlayerRanking(player: card.player, rank: idx + 1, total: 0)
        }
        let teams = ScoringEngine.autoPairTeams(rankings: rankings)
        if let i = t.rounds.firstIndex(where: { $0.index == 2 }) {
            t.rounds[i].teams = teams
        }
        await setRounds(t.rounds)
    }

    // MARK: - Local optimistic helpers

    private func applyLocalScore(_ entry: ScoreEntry) {
        guard var t = tournament else { return }
        t.scores.removeAll { $0.id == entry.id }
        t.scores.append(entry)
        tournament = t
    }

    private func applyLocalTeamScore(_ entry: TeamScoreEntry) {
        guard var t = tournament else { return }
        t.teamScores.removeAll { $0.id == entry.id }
        t.teamScores.append(entry)
        tournament = t
    }

    // MARK: - Read helpers used by views

    func leaderboard() -> [ScoringEngine.PlayerScorecard] {
        guard let t = tournament else { return [] }
        return ScoringEngine.leaderboard(t)
    }

    func round(_ index: Int) -> Round? {
        tournament?.rounds.first(where: { $0.index == index })
    }
}
