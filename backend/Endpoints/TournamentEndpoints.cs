using Microsoft.EntityFrameworkCore;
using RyderCup.Api.Data;
using RyderCup.Api.Models;

namespace RyderCup.Api.Endpoints;

public static class TournamentEndpoints
{
    public static void Map(WebApplication app)
    {
        var group = app.MapGroup("/api/tournaments");

        group.MapPost("/", async (CreateTournamentRequest req, RyderCupDbContext db) =>
        {
            var t = new Tournament
            {
                Name = string.IsNullOrWhiteSpace(req.Name) ? "Ryder Cup Trip" : req.Name!,
                Code = await GenerateUniqueCodeAsync(db),
            };
            db.Tournaments.Add(t);
            await db.SaveChangesAsync();
            return Results.Created($"/api/tournaments/{t.Code}", await BuildSnapshot(db, t));
        });

        group.MapGet("/{code}", async (string code, RyderCupDbContext db) =>
        {
            var t = await FindByCode(db, code);
            if (t is null) return Results.NotFound();
            return Results.Ok(await BuildSnapshot(db, t));
        });

        group.MapPatch("/{code}", async (string code, TournamentMetaUpdateRequest req, RyderCupDbContext db) =>
        {
            var t = await FindByCode(db, code);
            if (t is null) return Results.NotFound();
            if (req.Name is not null) t.Name = req.Name;
            if (req.Date is not null) t.Date = req.Date.Value;
            if (req.Players is not null) t.Players = req.Players;
            if (req.Course is not null) t.Course = req.Course;
            if (req.Rounds is not null) t.Rounds = req.Rounds;
            if (req.UseGhinHandicaps is not null) t.UseGhinHandicaps = req.UseGhinHandicaps.Value;
            if (req.BirdieEagleBonusEnabled is not null) t.BirdieEagleBonusEnabled = req.BirdieEagleBonusEnabled.Value;
            if (req.HandicapOverrides is not null) t.HandicapOverrides = req.HandicapOverrides;
            t.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
            return Results.Ok(await BuildSnapshot(db, t));
        });
    }

    public static async Task<Tournament?> FindByCode(RyderCupDbContext db, string code)
    {
        var norm = code.ToUpperInvariant();
        return await db.Tournaments.FirstOrDefaultAsync(t => t.Code == norm);
    }

    public static async Task<TournamentSnapshot> BuildSnapshot(RyderCupDbContext db, Tournament t)
    {
        var scores = await db.Scores.Where(s => s.TournamentId == t.Id).ToListAsync();
        var teamScores = await db.TeamScores.Where(s => s.TournamentId == t.Id).ToListAsync();
        var sideGames = await db.SideGames.Where(s => s.TournamentId == t.Id).ToListAsync();
        return new TournamentSnapshot(
            t.Id, t.Code, t.Name, t.Date, t.Players, t.Course, t.Rounds,
            t.UseGhinHandicaps, t.BirdieEagleBonusEnabled, t.HandicapOverrides,
            scores, teamScores, sideGames, t.UpdatedAt
        );
    }

    private static async Task<string> GenerateUniqueCodeAsync(RyderCupDbContext db)
    {
        // Excludes ambiguous chars (0/O, 1/I)
        const string alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
        var rng = Random.Shared;
        for (int attempt = 0; attempt < 50; attempt++)
        {
            var code = new string(Enumerable.Range(0, 6).Select(_ => alphabet[rng.Next(alphabet.Length)]).ToArray());
            if (!await db.Tournaments.AnyAsync(t => t.Code == code)) return code;
        }
        throw new InvalidOperationException("Could not generate unique tournament code");
    }
}
