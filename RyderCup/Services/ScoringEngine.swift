import Foundation

/// Pure, side-effect-free scoring computations.
///
/// Treat this file as the single authoritative source for tournament math.
/// Anything view-related (formatting, presentation) belongs in ViewModels.
enum ScoringEngine {

    // MARK: - Per-round gross totals

    /// Returns gross 18-hole total for a player in a given round, or nil if the
    /// player has not finished all 18 holes. If the round has a grossOverride
    /// entry for the player, that wins over hole-by-hole sums.
    static func grossTotal(
        playerId: String,
        roundIndex: Int,
        scores: [ScoreEntry],
        round: Round? = nil
    ) -> Int? {
        if let override = round?.grossOverrideMap[playerId] { return override }
        let playerScores = scores.filter { $0.playerId == playerId && $0.roundIndex == roundIndex }
        let unique = Dictionary(grouping: playerScores, by: { $0.holeNumber })
            .compactMapValues { $0.last }
        guard unique.count == 18 else { return nil }
        return unique.values.reduce(0) { $0 + $1.strokes }
    }

    /// Partial gross total (any number of completed holes). Useful for in-progress display.
    static func grossPartial(
        playerId: String,
        roundIndex: Int,
        scores: [ScoreEntry]
    ) -> Int {
        scores
            .filter { $0.playerId == playerId && $0.roundIndex == roundIndex }
            .reduce(0) { $0 + $1.strokes }
    }

    static func holesCompleted(
        playerId: String,
        roundIndex: Int,
        scores: [ScoreEntry]
    ) -> Int {
        Set(scores.filter { $0.playerId == playerId && $0.roundIndex == roundIndex }
            .map { $0.holeNumber }).count
    }

    // MARK: - Round 1: Individual stroke play

    /// Rank players 1..8 by gross total ascending. Ties share the higher rank
    /// (e.g. two tied at #2 both get rank 2, next gets rank 4) — but for points
    /// we average across the tied slots.
    static func rankPlayersGross(
        players: [Player],
        scores: [ScoreEntry],
        roundIndex: Int,
        round: Round? = nil
    ) -> [PlayerRanking] {
        let entries: [(Player, Int)] = players.compactMap { player in
            guard let total = grossTotal(playerId: player.id, roundIndex: roundIndex, scores: scores, round: round) else {
                return nil
            }
            return (player, total)
        }
        let sorted = entries.sorted { $0.1 < $1.1 }
        return assignRanks(sorted)
    }

    /// 1st=8pts, 2nd=7, ..., 8th=1. Ties split the sum of their slots evenly.
    /// Players who didn't complete the round receive 0.
    static func strokePlayPoints(_ rankings: [PlayerRanking], totalPlayers: Int = 8) -> [String: Double] {
        // Slot value for position i (1-indexed): totalPlayers - i + 1
        // i=1 -> 8, i=2 -> 7, ..., i=8 -> 1
        var points: [String: Double] = [:]
        // Group by rank, average the slot values across tied positions.
        let byRank = Dictionary(grouping: rankings, by: { $0.rank })
        for (rank, group) in byRank {
            let slotValues = (rank..<(rank + group.count)).map { Double(totalPlayers - $0 + 1) }
            let avg = slotValues.reduce(0, +) / Double(group.count)
            for r in group { points[r.player.id] = avg }
        }
        return points
    }

    // MARK: - Auto-pair teams (1/8, 2/7, 3/6, 4/5)

    /// Pair by current rank: highest with lowest. Used after R1 and before R3.
    /// Ties broken arbitrarily but stably by player id, so the same input
    /// produces the same teams.
    static func autoPairTeams(rankings: [PlayerRanking]) -> [Team] {
        // Sort by rank, then by playerId for tie stability.
        let ordered = rankings.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.player.id < $1.player.id
        }
        guard ordered.count == 8 else { return [] }
        let labels = ["A", "B", "C", "D"]
        return (0..<4).map { i in
            let top = ordered[i].player
            let bottom = ordered[7 - i].player
            return Team(
                id: labels[i],
                name: "Team \(labels[i])",
                playerIds: [top.id, bottom.id],
                seedLabel: "\(i + 1)/\(8 - i)"
            )
        }
    }

    /// Standard R2 matchup pattern: A vs D, B vs C.
    static func defaultBestBallMatchups(teams: [Team]) -> [Matchup] {
        guard teams.count == 4 else { return [] }
        return [
            Matchup(teamAId: teams[0].id, teamBId: teams[3].id),
            Matchup(teamAId: teams[1].id, teamBId: teams[2].id),
        ]
    }

    // MARK: - Round 2: 2-man Best Ball

    /// Per-hole best ball score for a team: the lower of the two players' strokes
    /// on that hole. Returns nil for any hole that doesn't have both players' scores.
    static func bestBallHoleScores(
        team: Team,
        roundIndex: Int,
        scores: [ScoreEntry]
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for hole in 1...18 {
            let holeScores = team.playerIds.compactMap { pid -> Int? in
                scores.first(where: { $0.playerId == pid && $0.roundIndex == roundIndex && $0.holeNumber == hole })?.strokes
            }
            if !holeScores.isEmpty {
                result[hole] = holeScores.min()
            }
        }
        return result
    }

    static func bestBallTotal(team: Team, roundIndex: Int, scores: [ScoreEntry], round: Round? = nil) -> Int? {
        // Manual override wins: if either teammate's gross total is overridden
        // for this round, we let users effectively override the team total by
        // overriding both players' gross. (Direct team-total override is only
        // wired for scramble, where one ball is in play.)
        let perHole = bestBallHoleScores(team: team, roundIndex: roundIndex, scores: scores)
        guard perHole.count == 18 else {
            // Fallback: if both players have a gross override, derive a synthetic
            // best-ball total by adding the player low totals proportionally.
            // We can't reconstruct true best ball without hole-by-hole, so we
            // approximate as the lower of the two players' overrides.
            let overrides = team.playerIds.compactMap { round?.grossOverrideMap[$0] }
            if overrides.count == team.playerIds.count, let lowest = overrides.min() {
                return lowest
            }
            return nil
        }
        return perHole.values.reduce(0, +)
    }

    /// Returns points awarded for each player in R2 based on:
    /// - 5 pts to winner of matchup (lower total best-ball score)
    /// - 2.5 pts each if tied
    /// - 2 bonus pts to each player on the team with the lowest total best-ball
    ///   score across all four teams (ties: split evenly)
    static func bestBallPoints(
        teams: [Team],
        matchups: [Matchup],
        roundIndex: Int,
        scores: [ScoreEntry],
        round: Round? = nil
    ) -> [String: Double] {
        var points: [String: Double] = [:]
        // Matchup outcomes
        for m in matchups {
            guard
                let teamA = teams.first(where: { $0.id == m.teamAId }),
                let teamB = teams.first(where: { $0.id == m.teamBId }),
                let totalA = bestBallTotal(team: teamA, roundIndex: roundIndex, scores: scores, round: round),
                let totalB = bestBallTotal(team: teamB, roundIndex: roundIndex, scores: scores, round: round)
            else { continue }
            if totalA < totalB {
                for pid in teamA.playerIds { points[pid, default: 0] += 5 }
            } else if totalB < totalA {
                for pid in teamB.playerIds { points[pid, default: 0] += 5 }
            } else {
                for pid in teamA.playerIds + teamB.playerIds { points[pid, default: 0] += 2.5 }
            }
        }
        // Lowest team score bonus (2 pts per player)
        let teamTotals: [(Team, Int)] = teams.compactMap {
            guard let t = bestBallTotal(team: $0, roundIndex: roundIndex, scores: scores, round: round) else { return nil }
            return ($0, t)
        }
        if let minTotal = teamTotals.map({ $0.1 }).min() {
            let winners = teamTotals.filter { $0.1 == minTotal }
            // Split bonus across tied teams: 2 pts split N ways per player
            let bonusPerTeam = 2.0 / Double(winners.count)
            for (team, _) in winners {
                for pid in team.playerIds { points[pid, default: 0] += bonusPerTeam }
            }
        }
        return points
    }

    // MARK: - Round 3: 2-man Scramble

    static func scrambleTeamTotal(team: Team, roundIndex: Int, teamScores: [TeamScoreEntry], round: Round? = nil) -> Int? {
        if let override = round?.teamScoreOverrideMap[team.id] { return override }
        let entries = teamScores.filter { $0.teamId == team.id && $0.roundIndex == roundIndex }
        let unique = Dictionary(grouping: entries, by: { $0.holeNumber }).compactMapValues { $0.last }
        guard unique.count == 18 else { return nil }
        return unique.values.reduce(0) { $0 + $1.strokes }
    }

    /// Ranks 4 teams, assigning 8/6/4/2 pts to each player on the team in rank order.
    /// Ties split evenly across the contested slots.
    static func scramblePoints(
        teams: [Team],
        roundIndex: Int,
        teamScores: [TeamScoreEntry],
        round: Round? = nil
    ) -> [String: Double] {
        let teamTotals: [(Team, Int)] = teams.compactMap {
            guard let t = scrambleTeamTotal(team: $0, roundIndex: roundIndex, teamScores: teamScores, round: round) else { return nil }
            return ($0, t)
        }
        let sorted = teamTotals.sorted { $0.1 < $1.1 }
        let slotValues: [Double] = [8, 6, 4, 2]
        var points: [String: Double] = [:]
        var i = 0
        while i < sorted.count {
            var j = i
            while j < sorted.count && sorted[j].1 == sorted[i].1 { j += 1 }
            // Tied teams from index i..<j share slotValues i..<j
            let slots = (i..<j).compactMap { slotValues.indices.contains($0) ? slotValues[$0] : nil }
            let avg = slots.isEmpty ? 0 : slots.reduce(0, +) / Double(slots.count)
            for k in i..<j {
                for pid in sorted[k].0.playerIds { points[pid, default: 0] += avg }
            }
            i = j
        }
        return points
    }

    // MARK: - Round 4: Net Stroke Play

    /// Derives course handicaps from Thursday R1 scores: best gross = scratch (0),
    /// everyone else gets strokes equal to (their gross − best gross), capped at 18.
    static func derivedHandicaps(
        players: [Player],
        scores: [ScoreEntry],
        round: Round? = nil
    ) -> [String: Int] {
        let totals: [(String, Int)] = players.compactMap { p in
            guard let t = grossTotal(playerId: p.id, roundIndex: 0, scores: scores, round: round) else { return nil }
            return (p.id, t)
        }
        guard let best = totals.map({ $0.1 }).min() else { return [:] }
        var hcps: [String: Int] = [:]
        for (id, t) in totals {
            hcps[id] = min(18, max(0, t - best))
        }
        return hcps
    }

    /// Returns course handicap to use for net scoring.
    /// Priority: manual override > GHIN (if enabled) > derived from R1.
    static func effectiveHandicaps(
        players: [Player],
        scores: [ScoreEntry],
        useGHIN: Bool,
        overrides: [String: Int] = [:],
        r1Round: Round? = nil
    ) -> [String: Int] {
        let derived = derivedHandicaps(players: players, scores: scores, round: r1Round)
        var result: [String: Int] = [:]
        for p in players {
            if let manual = overrides[p.id] {
                result[p.id] = max(0, min(54, manual))
            } else if useGHIN, let ghin = p.ghinHandicap {
                result[p.id] = max(0, min(54, Int(ghin.rounded())))
            } else {
                result[p.id] = derived[p.id] ?? 0
            }
        }
        return result
    }

    /// Net total = gross total − course handicap. Returns nil if the round
    /// isn't complete (and has no gross override).
    static func netTotal(
        playerId: String,
        scores: [ScoreEntry],
        handicaps: [String: Int],
        round: Round? = nil
    ) -> Int? {
        let idx = round?.index ?? 3
        guard let gross = grossTotal(playerId: playerId, roundIndex: idx, scores: scores, round: round) else { return nil }
        let hcp = handicaps[playerId] ?? 0
        return gross - hcp
    }

    static func netStrokePlayPoints(
        players: [Player],
        scores: [ScoreEntry],
        handicaps: [String: Int],
        round: Round? = nil
    ) -> [String: Double] {
        let totals: [(Player, Int)] = players.compactMap { p in
            guard let net = netTotal(playerId: p.id, scores: scores, handicaps: handicaps, round: round) else { return nil }
            return (p, net)
        }
        let sorted = totals.sorted { $0.1 < $1.1 }
        let rankings = assignRanks(sorted)
        return strokePlayPoints(rankings, totalPlayers: players.count)
    }

    // MARK: - Birdie / Eagle bonuses (across all 72 holes of stroke-style rounds)

    /// Counts birdies (1pt) and eagles (3pts) for each player across rounds that
    /// use individual stroke entries (R1, R2, R4). Skips R3 (scramble shares a ball).
    static func birdieEaglePoints(
        scores: [ScoreEntry],
        course: Course
    ) -> [String: Double] {
        var points: [String: Double] = [:]
        let parByHole = Dictionary(uniqueKeysWithValues: course.holes.map { ($0.number, $0.par) })
        for entry in scores where entry.roundIndex != 2 {
            guard let par = parByHole[entry.holeNumber] else { continue }
            let diff = entry.strokes - par
            if diff == -1 { points[entry.playerId, default: 0] += 1 }
            else if diff <= -2 { points[entry.playerId, default: 0] += 3 }
        }
        return points
    }

    // MARK: - Side Games

    static func sideGamePoints(_ entries: [SideGameEntry]) -> [String: Double] {
        entries.reduce(into: [:]) { acc, e in acc[e.playerId, default: 0] += e.points }
    }

    // MARK: - Cumulative Leaderboard

    /// Per-player breakdown of all point sources, in display order.
    struct PlayerScorecard: Identifiable {
        var player: Player
        var roundPoints: [Int: Double]  // roundIndex -> points
        var birdieEaglePoints: Double
        var sideGamePoints: Double
        var total: Double
        var id: String { player.id }
    }

    static func leaderboard(_ tournament: Tournament) -> [PlayerScorecard] {
        // Per-round point dictionaries. Each respects the round's
        // pointsOverride entries (per-player override).
        var perRound: [Int: [String: Double]] = [:]
        for round in tournament.rounds {
            perRound[round.index] = pointsForRound(round: round, tournament: tournament)
        }
        let be = tournament.birdieEagleBonusEnabled
            ? birdieEaglePoints(scores: tournament.scores, course: tournament.course)
            : [:]
        let sg = sideGamePoints(tournament.sideGames)

        let cards = tournament.players.map { p -> PlayerScorecard in
            let rp: [Int: Double] = [
                0: perRound[0]?[p.id] ?? 0,
                1: perRound[1]?[p.id] ?? 0,
                2: perRound[2]?[p.id] ?? 0,
                3: perRound[3]?[p.id] ?? 0,
            ]
            let total = rp.values.reduce(0, +) + (be[p.id] ?? 0) + (sg[p.id] ?? 0)
            return PlayerScorecard(
                player: p,
                roundPoints: rp,
                birdieEaglePoints: be[p.id] ?? 0,
                sideGamePoints: sg[p.id] ?? 0,
                total: total
            )
        }
        return cards.sorted { $0.total > $1.total }
    }

    /// Computes points for a single round honouring its format. Per-player
    /// pointsOverride entries replace the computed value for that player only.
    static func pointsForRound(round: Round, tournament: Tournament) -> [String: Double] {
        let computed: [String: Double] = {
            switch round.format {
            case .strokePlay:
                let ranks = rankPlayersGross(
                    players: tournament.players,
                    scores: tournament.scores,
                    roundIndex: round.index,
                    round: round
                )
                return strokePlayPoints(ranks, totalPlayers: tournament.players.count)
            case .bestBall:
                return bestBallPoints(
                    teams: round.teams,
                    matchups: round.matchups,
                    roundIndex: round.index,
                    scores: tournament.scores,
                    round: round
                )
            case .scramble:
                return scramblePoints(
                    teams: round.teams,
                    roundIndex: round.index,
                    teamScores: tournament.teamScores,
                    round: round
                )
            case .netStrokePlay:
                let r1 = tournament.rounds.first(where: { $0.index == 0 })
                let hcps = effectiveHandicaps(
                    players: tournament.players,
                    scores: tournament.scores,
                    useGHIN: tournament.useGHINHandicaps,
                    overrides: tournament.handicapOverridesMap,
                    r1Round: r1
                )
                return netStrokePlayPoints(
                    players: tournament.players,
                    scores: tournament.scores,
                    handicaps: hcps,
                    round: round
                )
            }
        }()
        // Merge in per-player overrides.
        var result = computed
        for (pid, pts) in round.pointsOverrideMap {
            result[pid] = pts
        }
        return result
    }

    // MARK: - Helpers

    struct PlayerRanking: Hashable {
        var player: Player
        var rank: Int
        var total: Int
    }

    /// Assigns ranks to a sorted (ascending by score) list, with ties sharing
    /// the same rank and the next rank skipping (e.g. 1, 2, 2, 4).
    private static func assignRanks(_ sorted: [(Player, Int)]) -> [PlayerRanking] {
        var result: [PlayerRanking] = []
        var i = 0
        while i < sorted.count {
            var j = i
            while j < sorted.count && sorted[j].1 == sorted[i].1 { j += 1 }
            for k in i..<j {
                result.append(PlayerRanking(player: sorted[k].0, rank: i + 1, total: sorted[k].1))
            }
            i = j
        }
        return result
    }
}
