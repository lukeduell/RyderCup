using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RyderCup.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddHandicapOverrides : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "HandicapOverrides",
                table: "Tournaments",
                type: "jsonb",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HandicapOverrides",
                table: "Tournaments");
        }
    }
}
