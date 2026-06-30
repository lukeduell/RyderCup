using Microsoft.EntityFrameworkCore;
using RyderCup.Api.Data;
using RyderCup.Api.Models;

namespace RyderCup.Api.Endpoints;

public static class SideGameEndpoints
{
    public static void Map(WebApplication app)
    {
        var group = app.MapGroup("/api/tournaments/{code}");

        group.MapPost("/side-games", async (string code, SideGameUpsertRequest req, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            if (req.Id is Guid existingId &&
                await db.SideGames.FirstOrDefaultAsync(s => s.Id == existingId && s.TournamentId == t.Id) is { } existing)
            {
                existing.Type = req.Type;
                existing.PlayerId = req.PlayerId;
                existing.RoundIndex = req.RoundIndex;
                existing.HoleNumber = req.HoleNumber;
                existing.Points = req.Points;
                existing.Note = req.Note;
            }
            else
            {
                db.SideGames.Add(new SideGameEntry
                {
                    Id = req.Id ?? Guid.NewGuid(),
                    TournamentId = t.Id,
                    Type = req.Type,
                    PlayerId = req.PlayerId,
                    RoundIndex = req.RoundIndex,
                    HoleNumber = req.HoleNumber,
                    Points = req.Points,
                    Note = req.Note,
                });
            }
            t.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
            return Results.Ok();
        });

        group.MapDelete("/side-games/{id:guid}", async (string code, Guid id, RyderCupDbContext db) =>
        {
            var t = await TournamentEndpoints.FindByCode(db, code);
            if (t is null) return Results.NotFound();
            var existing = await db.SideGames.FirstOrDefaultAsync(s => s.Id == id && s.TournamentId == t.Id);
            if (existing is not null)
            {
                db.SideGames.Remove(existing);
                t.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync();
            }
            return Results.NoContent();
        });
    }
}
