using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RyderCup.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Scores",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    TournamentId = table.Column<Guid>(type: "uuid", nullable: false),
                    PlayerId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RoundIndex = table.Column<int>(type: "integer", nullable: false),
                    HoleNumber = table.Column<int>(type: "integer", nullable: false),
                    Strokes = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Scores", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SideGames",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TournamentId = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    PlayerId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RoundIndex = table.Column<int>(type: "integer", nullable: true),
                    HoleNumber = table.Column<int>(type: "integer", nullable: true),
                    Points = table.Column<double>(type: "double precision", nullable: false),
                    Note = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SideGames", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TeamScores",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    TournamentId = table.Column<Guid>(type: "uuid", nullable: false),
                    TeamId = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    RoundIndex = table.Column<int>(type: "integer", nullable: false),
                    HoleNumber = table.Column<int>(type: "integer", nullable: false),
                    Strokes = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TeamScores", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Tournaments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Date = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Players = table.Column<string>(type: "jsonb", nullable: false),
                    Course = table.Column<string>(type: "jsonb", nullable: false),
                    Rounds = table.Column<string>(type: "jsonb", nullable: false),
                    UseGhinHandicaps = table.Column<bool>(type: "boolean", nullable: false),
                    BirdieEagleBonusEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tournaments", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Scores_TournamentId",
                table: "Scores",
                column: "TournamentId");

            migrationBuilder.CreateIndex(
                name: "IX_Scores_TournamentId_PlayerId_RoundIndex_HoleNumber",
                table: "Scores",
                columns: new[] { "TournamentId", "PlayerId", "RoundIndex", "HoleNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SideGames_TournamentId",
                table: "SideGames",
                column: "TournamentId");

            migrationBuilder.CreateIndex(
                name: "IX_TeamScores_TournamentId",
                table: "TeamScores",
                column: "TournamentId");

            migrationBuilder.CreateIndex(
                name: "IX_TeamScores_TournamentId_TeamId_RoundIndex_HoleNumber",
                table: "TeamScores",
                columns: new[] { "TournamentId", "TeamId", "RoundIndex", "HoleNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Tournaments_Code",
                table: "Tournaments",
                column: "Code",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Scores");

            migrationBuilder.DropTable(
                name: "SideGames");

            migrationBuilder.DropTable(
                name: "TeamScores");

            migrationBuilder.DropTable(
                name: "Tournaments");
        }
    }
}
