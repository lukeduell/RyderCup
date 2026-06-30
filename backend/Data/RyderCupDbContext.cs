using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RyderCup.Api.Models;

namespace RyderCup.Api.Data;

public class RyderCupDbContext : DbContext
{
    public DbSet<Tournament> Tournaments => Set<Tournament>();
    public DbSet<ScoreEntry> Scores => Set<ScoreEntry>();
    public DbSet<TeamScoreEntry> TeamScores => Set<TeamScoreEntry>();
    public DbSet<SideGameEntry> SideGames => Set<SideGameEntry>();

    public RyderCupDbContext(DbContextOptions<RyderCupDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder model)
    {
        var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

        var tournament = model.Entity<Tournament>();
        tournament.HasIndex(t => t.Code).IsUnique();

        tournament.Property(t => t.Players)
            .HasColumnType("jsonb")
            .HasConversion(
                v => JsonSerializer.Serialize(v, jsonOptions),
                v => JsonSerializer.Deserialize<List<Player>>(v, jsonOptions) ?? new());

        tournament.Property(t => t.Course)
            .HasColumnType("jsonb")
            .HasConversion(
                v => JsonSerializer.Serialize(v, jsonOptions),
                v => JsonSerializer.Deserialize<Course>(v, jsonOptions) ?? Course.Blank());

        tournament.Property(t => t.Rounds)
            .HasColumnType("jsonb")
            .HasConversion(
                v => JsonSerializer.Serialize(v, jsonOptions),
                v => JsonSerializer.Deserialize<List<Round>>(v, jsonOptions) ?? new());

        tournament.Property(t => t.HandicapOverrides)
            .HasColumnType("jsonb")
            .HasConversion(
                v => JsonSerializer.Serialize(v, jsonOptions),
                v => JsonSerializer.Deserialize<Dictionary<string, int>>(v, jsonOptions) ?? new());

        tournament.Ignore(t => t.Scores);
        tournament.Ignore(t => t.TeamScores);
        tournament.Ignore(t => t.SideGames);

        var score = model.Entity<ScoreEntry>();
        score.HasIndex(s => new { s.TournamentId, s.PlayerId, s.RoundIndex, s.HoleNumber }).IsUnique();
        score.HasIndex(s => s.TournamentId);

        var teamScore = model.Entity<TeamScoreEntry>();
        teamScore.HasIndex(s => new { s.TournamentId, s.TeamId, s.RoundIndex, s.HoleNumber }).IsUnique();
        teamScore.HasIndex(s => s.TournamentId);

        var side = model.Entity<SideGameEntry>();
        side.HasIndex(s => s.TournamentId);
    }
}
