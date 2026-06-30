namespace RyderCup.Api.Models;

public record CreateTournamentRequest(string? Name);

public record TournamentMetaUpdateRequest(
    string? Name,
    DateTime? Date,
    List<Player>? Players,
    Course? Course,
    List<Round>? Rounds,
    bool? UseGhinHandicaps,
    bool? BirdieEagleBonusEnabled,
    Dictionary<string, int>? HandicapOverrides,
    bool? AutoFetchEnabled
);

public record ScoreUpsertRequest(string PlayerId, int RoundIndex, int HoleNumber, int Strokes);

public record TeamScoreUpsertRequest(string TeamId, int RoundIndex, int HoleNumber, int Strokes);

public record SideGameUpsertRequest(
    Guid? Id,
    string Type,
    string PlayerId,
    int? RoundIndex,
    int? HoleNumber,
    double Points,
    string? Note
);

public record TournamentSnapshot(
    Guid Id,
    string Code,
    string Name,
    DateTime Date,
    List<Player> Players,
    Course Course,
    List<Round> Rounds,
    bool UseGhinHandicaps,
    bool BirdieEagleBonusEnabled,
    Dictionary<string, int> HandicapOverrides,
    bool AutoFetchEnabled,
    List<ScoreEntry> Scores,
    List<TeamScoreEntry> TeamScores,
    List<SideGameEntry> SideGames,
    DateTime UpdatedAt
);
