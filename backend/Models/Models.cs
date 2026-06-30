using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RyderCup.Api.Models;

// ---------- EF entities ----------

public class Tournament
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [MaxLength(8)]
    public string Code { get; set; } = "";

    [MaxLength(200)]
    public string Name { get; set; } = "Ryder Cup Trip";

    public DateTime Date { get; set; } = DateTime.UtcNow;

    // JSONB columns — full sub-object on each PATCH; concurrent edits are rare.
    public List<Player> Players { get; set; } = new();
    public Course Course { get; set; } = Course.Blank();
    public List<Round> Rounds { get; set; } = DefaultRounds();

    public bool UseGhinHandicaps { get; set; } = false;
    public bool BirdieEagleBonusEnabled { get; set; } = true;

    /// Global admin-controlled toggle: when true (default), every connected
    /// device polls the API every few seconds. When false, refresh is manual
    /// only (pull-down / refresh button).
    public bool AutoFetchEnabled { get; set; } = true;

    /// Player id → manual handicap. Overrides GHIN and derived (R1-based) handicap.
    public Dictionary<string, int> HandicapOverrides { get; set; } = new();

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<ScoreEntry> Scores { get; set; } = new();
    public List<TeamScoreEntry> TeamScores { get; set; } = new();
    public List<SideGameEntry> SideGames { get; set; } = new();

    private static List<Round> DefaultRounds() => new()
    {
        new Round { Index = 0, Name = "Thursday",    Format = RoundFormat.StrokePlay },
        new Round { Index = 1, Name = "Friday",      Format = RoundFormat.BestBall },
        new Round { Index = 2, Name = "Saturday AM", Format = RoundFormat.Scramble },
        new Round { Index = 3, Name = "Saturday PM", Format = RoundFormat.NetStrokePlay },
    };
}

public class ScoreEntry
{
    [Key]
    [MaxLength(80)]
    public string Id { get; set; } = "";

    public Guid TournamentId { get; set; }

    [MaxLength(64)]
    public string PlayerId { get; set; } = "";

    public int RoundIndex { get; set; }
    public int HoleNumber { get; set; }
    public int Strokes { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public static string MakeId(string playerId, int roundIndex, int holeNumber)
        => $"{playerId}_r{roundIndex}_h{holeNumber}";
}

public class TeamScoreEntry
{
    [Key]
    [MaxLength(80)]
    public string Id { get; set; } = "";

    public Guid TournamentId { get; set; }

    [MaxLength(8)]
    public string TeamId { get; set; } = "";

    public int RoundIndex { get; set; }
    public int HoleNumber { get; set; }
    public int Strokes { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public static string MakeId(string teamId, int roundIndex, int holeNumber)
        => $"{teamId}_r{roundIndex}_h{holeNumber}";
}

public class SideGameEntry
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TournamentId { get; set; }

    [MaxLength(32)]
    public string Type { get; set; } = "";

    [MaxLength(64)]
    public string PlayerId { get; set; } = "";

    public int? RoundIndex { get; set; }
    public int? HoleNumber { get; set; }
    public double Points { get; set; }

    [MaxLength(200)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

// ---------- JSONB sub-types (stored in tournament row) ----------

public class Player
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public double? GhinHandicap { get; set; }
}

public class Hole
{
    public int Number { get; set; }
    public int Par { get; set; } = 4;
    public int HandicapIndex { get; set; }
    public int? Yardage { get; set; }
}

public class Course
{
    public string Name { get; set; } = "Course TBD";
    public List<Hole> Holes { get; set; } = new();

    public static Course Blank()
    {
        var c = new Course();
        for (int n = 1; n <= 18; n++)
        {
            int par = (n == 3 || n == 7 || n == 12 || n == 16) ? 3
                : (n == 5 || n == 14) ? 5
                : 4;
            c.Holes.Add(new Hole { Number = n, Par = par, HandicapIndex = n });
        }
        return c;
    }
}

public enum RoundFormat { StrokePlay, BestBall, Scramble, NetStrokePlay }
public enum RoundStatus { NotStarted, InProgress, Completed }

public class Team
{
    public string Id { get; set; } = "";     // "A".."D"
    public string Name { get; set; } = "";
    public List<string> PlayerIds { get; set; } = new();
    public string? SeedLabel { get; set; }
}

public class Matchup
{
    public string TeamAId { get; set; } = "";
    public string TeamBId { get; set; } = "";
}

public class Round
{
    public int Index { get; set; }
    public string Name { get; set; } = "";
    public RoundFormat Format { get; set; } = RoundFormat.StrokePlay;
    public RoundStatus Status { get; set; } = RoundStatus.NotStarted;
    public List<Team> Teams { get; set; } = new();
    public List<Matchup> Matchups { get; set; } = new();

    /// Player id → final round points. Replaces computed value for that player.
    public Dictionary<string, double> PointsOverride { get; set; } = new();

    /// Player id → 18-hole gross total. Replaces summed hole scores.
    public Dictionary<string, int> GrossOverride { get; set; } = new();

    /// Team id → 18-hole scramble total. Replaces summed team scores.
    public Dictionary<string, int> TeamScoreOverride { get; set; } = new();
}
