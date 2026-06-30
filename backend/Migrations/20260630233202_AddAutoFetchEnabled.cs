using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RyderCup.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAutoFetchEnabled : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AutoFetchEnabled",
                table: "Tournaments",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AutoFetchEnabled",
                table: "Tournaments");
        }
    }
}
