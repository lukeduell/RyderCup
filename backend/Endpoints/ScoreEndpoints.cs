using Microsoft.EntityFrameworkCore;
using RyderCup.Api.Data;
using RyderCup.Api.Models;

namespace RyderCup.Api.Endpoints;

public static class ScoreEndpoints
{
    public static void Map(WebApplication app)
    {
        var group = app.MapGroup("/api/tournaments/{code}");

        group.MapPost("/scores", async (string code, ScoreUpsertRequest req, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            var id = ScoreEntry.MakeId(req.PlayerId, req.RoundIndex, req.HoleNumber);
            var existing = await db.Scores.FirstOrDefaultAsync(s => s.Id == id && s.TournamentId == t.Id);
            if (existing is null)
            {
                db.Scores.Add(new ScoreEntry
                {
                    Id = id,
                    TournamentId = t.Id,
                    PlayerId = req.PlayerId,
                    RoundIndex = req.RoundIndex,
                    HoleNumber = req.HoleNumber,
                    Strokes = req.Strokes,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            else
            {
                existing.Strokes = req.Strokes;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            t.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
            return Results.Ok();
        });

        group.MapDelete("/scores/{playerId}/{roundIndex:int}/{holeNumber:int}",
            async (string code, string playerId, int roundIndex, int holeNumber, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            var id = ScoreEntry.MakeId(playerId, roundIndex, holeNumber);
            var existing = await db.Scores.FirstOrDefaultAsync(s => s.Id == id && s.TournamentId == t.Id);
            if (existing is not null)
            {
                db.Scores.Remove(existing);
                t.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync();
            }
            return Results.NoContent();
        });

        group.MapPost("/team-scores", async (string code, TeamScoreUpsertRequest req, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            var id = TeamScoreEntry.MakeId(req.TeamId, req.RoundIndex, req.HoleNumber);
            var existing = await db.TeamScores.FirstOrDefaultAsync(s => s.Id == id && s.TournamentId == t.Id);
            if (existing is null)
            {
                db.TeamScores.Add(new TeamScoreEntry
                {
                    Id = id,
                    TournamentId = t.Id,
                    TeamId = req.TeamId,
                    RoundIndex = req.RoundIndex,
                    HoleNumber = req.HoleNumber,
                    Strokes = req.Strokes,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            else
            {
                existing.Strokes = req.Strokes;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            t.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
            return Results.Ok();
        });

        group.MapDelete("/team-scores/{teamId}/{roundIndex:int}/{holeNumber:int}",
            async (string code, string teamId, int roundIndex, int holeNumber, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            var id = TeamScoreEntry.MakeId(teamId, roundIndex, holeNumber);
            var existing = await db.TeamScores.FirstOrDefaultAsync(s => s.Id == id && s.TournamentId == t.Id);
            if (existing is not null)
            {
                db.TeamScores.Remove(existing);
                t.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync();
            }
            return Results.NoContent();
        });
    }
}
