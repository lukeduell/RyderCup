import XCTest
@testable import RyderCup

final class ScoringEngineTests: XCTestCase {

    // Helpers

    private func makeCourse() -> Course {
        var holes: [Hole] = []
        for n in 1...18 {
            let par = (n == 3 || n == 7 || n == 12 || n == 16) ? 3
                : (n == 5 || n == 14) ? 5
                : 4
            holes.append(Hole(number: n, par: par, handicapIndex: n))
        }
        return Course(name: "Test", holes: holes)
    }

    private func makePlayers(_ count: Int = 8) -> [Player] {
        (1...count).map { Player(id: "p\($0)", name: "P\($0)") }
    }

    private func makeFlatRound(player: Player, roundIndex: Int, strokesPerHole: Int) -> [ScoreEntry] {
        (1...18).map {
            ScoreEntry(playerId: player.id, roundIndex: roundIndex, holeNumber: $0, strokes: strokesPerHole)
        }
    }

    private func makeRound(player: Player, roundIndex: Int, totalStrokes: Int) -> [ScoreEntry] {
        // Distribute total over 18 holes (mostly equal, remainder front-loaded).
        let base = totalStrokes / 18
        let extra = totalStrokes % 18
        return (1...18).map { hole in
            let s = hole <= extra ? base + 1 : base
            return ScoreEntry(playerId: player.id, roundIndex: roundIndex, holeNumber: hole, strokes: s)
        }
    }

    // MARK: - R1 ranking

    func testStrokePlayRanksDistinctScores() {
        let players = makePlayers(8)
        var scores: [ScoreEntry] = []
        // Player 1=72, P2=73, ..., P8=79
        for (i, p) in players.enumerated() {
            scores += makeRound(player: p, roundIndex: 0, totalStrokes: 72 + i)
        }
        let rankings = ScoringEngine.rankPlayersGross(players: players, scores: scores, roundIndex: 0)
        XCTAssertEqual(rankings.count, 8)
        XCTAssertEqual(rankings.first?.player.id, "p1")
        XCTAssertEqual(rankings.first?.rank, 1)
        XCTAssertEqual(rankings.last?.player.id, "p8")
        XCTAssertEqual(rankings.last?.rank, 8)

        let pts = ScoringEngine.strokePlayPoints(rankings, totalPlayers: 8)
        XCTAssertEqual(pts["p1"], 8)
        XCTAssertEqual(pts["p2"], 7)
        XCTAssertEqual(pts["p8"], 1)
        XCTAssertEqual(pts.values.reduce(0, +), Double(8+7+6+5+4+3+2+1))
    }

    func testStrokePlayHandlesTwoWayTie() {
        let players = makePlayers(8)
        var scores: [ScoreEntry] = []
        // P1=P2=72, P3=73, P4=74, ..., P8=78
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 72)
        scores += makeRound(player: players[1], roundIndex: 0, totalStrokes: 72)
        for i in 2..<8 {
            scores += makeRound(player: players[i], roundIndex: 0, totalStrokes: 71 + i)
        }
        let rankings = ScoringEngine.rankPlayersGross(players: players, scores: scores, roundIndex: 0)
        // P1 and P2 both rank 1; P3 ranks 3
        XCTAssertEqual(rankings.filter { $0.rank == 1 }.count, 2)
        XCTAssertEqual(rankings.first(where: { $0.player.id == "p3" })?.rank, 3)

        let pts = ScoringEngine.strokePlayPoints(rankings, totalPlayers: 8)
        // Tied players get average of slot 1 (8 pts) and slot 2 (7 pts) = 7.5
        XCTAssertEqual(pts["p1"], 7.5)
        XCTAssertEqual(pts["p2"], 7.5)
        XCTAssertEqual(pts["p3"], 6)
        // Total points conserved
        XCTAssertEqual(pts.values.reduce(0, +), 36)
    }

    // MARK: - Team pairing

    func testAutoPairTeams1_8() {
        let players = makePlayers(8)
        var scores: [ScoreEntry] = []
        for (i, p) in players.enumerated() {
            scores += makeRound(player: p, roundIndex: 0, totalStrokes: 72 + i)
        }
        let rankings = ScoringEngine.rankPlayersGross(players: players, scores: scores, roundIndex: 0)
        let teams = ScoringEngine.autoPairTeams(rankings: rankings)
        XCTAssertEqual(teams.count, 4)
        // Team A = rank 1 + rank 8
        XCTAssertEqual(Set(teams[0].playerIds), Set(["p1", "p8"]))
        XCTAssertEqual(Set(teams[1].playerIds), Set(["p2", "p7"]))
        XCTAssertEqual(Set(teams[2].playerIds), Set(["p3", "p6"]))
        XCTAssertEqual(Set(teams[3].playerIds), Set(["p4", "p5"]))
        XCTAssertEqual(teams[0].seedLabel, "1/8")
    }

    // MARK: - R2 Best Ball

    func testBestBallTeamScoreIsLowerOfTwo() {
        let players = makePlayers(2)
        let team = Team(id: "A", name: "A", playerIds: ["p1", "p2"])
        var scores: [ScoreEntry] = []
        // P1 shoots 5 on every hole; P2 shoots 4 on every hole. Best ball total = 72.
        for hole in 1...18 {
            scores.append(ScoreEntry(playerId: "p1", roundIndex: 1, holeNumber: hole, strokes: 5))
            scores.append(ScoreEntry(playerId: "p2", roundIndex: 1, holeNumber: hole, strokes: 4))
        }
        let total = ScoringEngine.bestBallTotal(team: team, roundIndex: 1, scores: scores)
        XCTAssertEqual(total, 72)
        _ = players
    }

    func testBestBallMatchupAwardsFive() {
        let players = makePlayers(4)
        let teamA = Team(id: "A", name: "A", playerIds: ["p1", "p2"])
        let teamB = Team(id: "B", name: "B", playerIds: ["p3", "p4"])
        var scores: [ScoreEntry] = []
        // Team A best ball = 70 (4s and 3 fives), Team B = 75 (all 4s, one 5 — actually let's make B clearly worse)
        for hole in 1...18 {
            scores.append(ScoreEntry(playerId: "p1", roundIndex: 1, holeNumber: hole, strokes: 4))
            scores.append(ScoreEntry(playerId: "p2", roundIndex: 1, holeNumber: hole, strokes: 5))
            // p3, p4: both 5 each — best ball = 90
            scores.append(ScoreEntry(playerId: "p3", roundIndex: 1, holeNumber: hole, strokes: 5))
            scores.append(ScoreEntry(playerId: "p4", roundIndex: 1, holeNumber: hole, strokes: 5))
        }
        let matchup = Matchup(teamAId: "A", teamBId: "B")
        let pts = ScoringEngine.bestBallPoints(
            teams: [teamA, teamB],
            matchups: [matchup],
            roundIndex: 1,
            scores: scores
        )
        // Team A wins matchup (5 pts each) + lowest team score bonus (2 pts each) = 7 pts each
        XCTAssertEqual(pts["p1"], 7)
        XCTAssertEqual(pts["p2"], 7)
        XCTAssertEqual(pts["p3"] ?? 0, 0)
        XCTAssertEqual(pts["p4"] ?? 0, 0)
        _ = players
    }

    func testBestBallTieAwardsHalfPoints() {
        let teamA = Team(id: "A", name: "A", playerIds: ["p1", "p2"])
        let teamB = Team(id: "B", name: "B", playerIds: ["p3", "p4"])
        var scores: [ScoreEntry] = []
        // All players shoot 4 every hole. Both team best balls = 72. Tied.
        for hole in 1...18 {
            for pid in ["p1", "p2", "p3", "p4"] {
                scores.append(ScoreEntry(playerId: pid, roundIndex: 1, holeNumber: hole, strokes: 4))
            }
        }
        let pts = ScoringEngine.bestBallPoints(
            teams: [teamA, teamB],
            matchups: [Matchup(teamAId: "A", teamBId: "B")],
            roundIndex: 1,
            scores: scores
        )
        // Both teams tie: 2.5 each, both share lowest bonus split: (2/2) = 1 each
        XCTAssertEqual(pts["p1"], 3.5)
        XCTAssertEqual(pts["p4"], 3.5)
    }

    // MARK: - R3 Scramble

    func testScrambleRanksAndAwardsPoints() {
        let teams = [
            Team(id: "A", name: "A", playerIds: ["p1", "p2"]),
            Team(id: "B", name: "B", playerIds: ["p3", "p4"]),
            Team(id: "C", name: "C", playerIds: ["p5", "p6"]),
            Team(id: "D", name: "D", playerIds: ["p7", "p8"]),
        ]
        var teamScores: [TeamScoreEntry] = []
        // A=70, B=72, C=74, D=76
        for hole in 1...18 {
            teamScores.append(TeamScoreEntry(teamId: "A", roundIndex: 2, holeNumber: hole, strokes: hole <= 16 ? 4 : 3))
            teamScores.append(TeamScoreEntry(teamId: "B", roundIndex: 2, holeNumber: hole, strokes: 4))
            teamScores.append(TeamScoreEntry(teamId: "C", roundIndex: 2, holeNumber: hole, strokes: hole <= 4 ? 5 : 4))
            teamScores.append(TeamScoreEntry(teamId: "D", roundIndex: 2, holeNumber: hole, strokes: hole <= 8 ? 5 : 4))
        }
        let pts = ScoringEngine.scramblePoints(teams: teams, roundIndex: 2, teamScores: teamScores)
        XCTAssertEqual(pts["p1"], 8)
        XCTAssertEqual(pts["p2"], 8)
        XCTAssertEqual(pts["p3"], 6)
        XCTAssertEqual(pts["p5"], 4)
        XCTAssertEqual(pts["p7"], 2)
    }

    // MARK: - R4 Handicap derivation + Net

    func testDerivedHandicapsFromR1() {
        let players = makePlayers(4)
        var scores: [ScoreEntry] = []
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 70)
        scores += makeRound(player: players[1], roundIndex: 0, totalStrokes: 80)
        scores += makeRound(player: players[2], roundIndex: 0, totalStrokes: 92)
        // P4: gross 105 → diff 35, but capped at 18
        scores += makeRound(player: players[3], roundIndex: 0, totalStrokes: 105)
        let hcps = ScoringEngine.derivedHandicaps(players: players, scores: scores)
        XCTAssertEqual(hcps["p1"], 0)
        XCTAssertEqual(hcps["p2"], 10)
        XCTAssertEqual(hcps["p3"], 18)  // 92 - 70 = 22, capped at 18
        XCTAssertEqual(hcps["p4"], 18)
    }

    func testNetStrokePlayPointsRespectHandicaps() {
        let players = makePlayers(4)
        var scores: [ScoreEntry] = []
        // R1 sets handicaps: p1=0, p2=10, p3=18, p4=18 (capped)
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 70)
        scores += makeRound(player: players[1], roundIndex: 0, totalStrokes: 80)
        scores += makeRound(player: players[2], roundIndex: 0, totalStrokes: 90)
        scores += makeRound(player: players[3], roundIndex: 0, totalStrokes: 100)
        // R4 gross: p1=75, p2=85, p3=80, p4=95
        scores += makeRound(player: players[0], roundIndex: 3, totalStrokes: 75)  // net 75
        scores += makeRound(player: players[1], roundIndex: 3, totalStrokes: 85)  // net 75
        scores += makeRound(player: players[2], roundIndex: 3, totalStrokes: 80)  // net 62 (best)
        scores += makeRound(player: players[3], roundIndex: 3, totalStrokes: 95)  // net 77
        let hcps = ScoringEngine.derivedHandicaps(players: players, scores: scores)
        let pts = ScoringEngine.netStrokePlayPoints(players: players, scores: scores, handicaps: hcps)
        // Ranked by net: p3(62), p1(75)/p2(75) tied, p4(77)
        XCTAssertEqual(pts["p3"], 4)  // 1st of 4
        // Tie at 2nd: avg of (3, 2) = 2.5
        XCTAssertEqual(pts["p1"], 2.5)
        XCTAssertEqual(pts["p2"], 2.5)
        XCTAssertEqual(pts["p4"], 1)
    }

    // MARK: - Overrides

    func testGrossOverrideReplacesHoleScores() {
        let players = makePlayers(2)
        var scores: [ScoreEntry] = []
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 90)
        // p2 has only partial scores (10 holes) — would normally be ineligible
        for h in 1...10 {
            scores.append(ScoreEntry(playerId: "p2", roundIndex: 0, holeNumber: h, strokes: 5))
        }
        // But with a grossOverride for p2, we should still get a total back.
        let round = Round(index: 0, name: "T", format: .strokePlay, grossOverride: ["p2": 88])
        let totalP1 = ScoringEngine.grossTotal(playerId: "p1", roundIndex: 0, scores: scores, round: round)
        let totalP2 = ScoringEngine.grossTotal(playerId: "p2", roundIndex: 0, scores: scores, round: round)
        XCTAssertEqual(totalP1, 90)
        XCTAssertEqual(totalP2, 88)
    }

    func testHandicapOverrideWinsOverGhinAndDerived() {
        let players = [
            Player(id: "p1", name: "A", ghinHandicap: 12),
            Player(id: "p2", name: "B", ghinHandicap: 20),
        ]
        var scores: [ScoreEntry] = []
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 72)
        scores += makeRound(player: players[1], roundIndex: 0, totalStrokes: 92)
        // Derived: p1=0, p2=18. GHIN says p1=12, p2=20. Override says p1=5.
        let hcps = ScoringEngine.effectiveHandicaps(
            players: players,
            scores: scores,
            useGHIN: true,
            overrides: ["p1": 5]
        )
        XCTAssertEqual(hcps["p1"], 5)   // override
        XCTAssertEqual(hcps["p2"], 20)  // GHIN
    }

    func testPointsOverrideReplacesComputedPerPlayer() {
        let players = makePlayers(4)
        var scores: [ScoreEntry] = []
        scores += makeRound(player: players[0], roundIndex: 0, totalStrokes: 72)
        scores += makeRound(player: players[1], roundIndex: 0, totalStrokes: 75)
        scores += makeRound(player: players[2], roundIndex: 0, totalStrokes: 78)
        scores += makeRound(player: players[3], roundIndex: 0, totalStrokes: 80)
        var t = Tournament(
            id: "t1", name: "T", date: Date(),
            players: players, course: makeCourse(),
            rounds: [Round(index: 0, name: "Thu", format: .strokePlay)],
            scores: scores, teamScores: [], sideGames: [],
            useGHINHandicaps: false, birdieEagleBonusEnabled: false
        )
        // Override p3 to 999 — they should win regardless of gross.
        t.rounds[0].pointsOverride = ["p3": 999]
        let pts = ScoringEngine.pointsForRound(round: t.rounds[0], tournament: t)
        XCTAssertEqual(pts["p3"], 999)
        // Untouched players still ranked normally.
        XCTAssertEqual(pts["p1"], 4)  // would be 4 of 4 players (4 = max)
    }

    func testTeamScoreOverrideForScramble() {
        let teams = [
            Team(id: "A", name: "A", playerIds: ["p1", "p2"]),
            Team(id: "B", name: "B", playerIds: ["p3", "p4"]),
        ]
        // Only entered a few scramble holes — partial. With overrides, both teams
        // should still rank.
        let teamScores: [TeamScoreEntry] = [
            TeamScoreEntry(teamId: "A", roundIndex: 2, holeNumber: 1, strokes: 4),
        ]
        let round = Round(
            index: 2,
            name: "Sat AM",
            format: .scramble,
            teams: teams,
            teamScoreOverride: ["A": 70, "B": 75]
        )
        let pts = ScoringEngine.scramblePoints(teams: teams, roundIndex: 2, teamScores: teamScores, round: round)
        // A=70 wins, B=75 loses. Only 2 teams, so 1st=8, 2nd=6.
        XCTAssertEqual(pts["p1"], 8)
        XCTAssertEqual(pts["p3"], 6)
    }

    // MARK: - Birdie / Eagle bonus

    func testBirdieEagleBonusOnlyForIndividualRounds() {
        let course = makeCourse()
        // Round 1, hole 5 (par 5) — player shoots 4 (birdie = 1 pt)
        // Round 1, hole 3 (par 3) — player shoots 1 (eagle? 2 under par 3 → 1 stroke = 2 under = eagle = 3 pts)
        // Round 3 (scramble) — bird shouldn't count.
        var scores: [ScoreEntry] = []
        scores.append(ScoreEntry(playerId: "p1", roundIndex: 0, holeNumber: 5, strokes: 4))   // birdie on par 5
        scores.append(ScoreEntry(playerId: "p1", roundIndex: 0, holeNumber: 3, strokes: 1))   // hole in one (eagle/ace)
        scores.append(ScoreEntry(playerId: "p1", roundIndex: 2, holeNumber: 5, strokes: 4))   // birdie scramble — ignored
        let pts = ScoringEngine.birdieEaglePoints(scores: scores, course: course)
        XCTAssertEqual(pts["p1"], 4)
    }
}
