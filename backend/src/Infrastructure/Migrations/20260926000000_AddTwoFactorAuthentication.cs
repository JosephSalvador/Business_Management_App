using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <summary>
    /// Adds second-factor state to users, device metadata to refresh tokens, and the
    /// recovery-code table.
    ///
    /// Hand-authored rather than scaffolded: at the time of writing the toolchain was
    /// unavailable, so the schema, the model snapshot, and this migration were edited
    /// together. The next `migrations add` must produce an empty diff — if it does not,
    /// one of the three is out of sync and that is the bug to fix, not this file.
    /// </summary>
    public partial class AddTwoFactorAuthentication : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "TwoFactorEnabled",
                schema: "public",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "TwoFactorEnabledAt",
                schema: "public",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TwoFactorPendingSecret",
                schema: "public",
                table: "Users",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TwoFactorSecret",
                schema: "public",
                table: "Users",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeviceLabel",
                schema: "public",
                table: "RefreshTokens",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "IpAddress",
                schema: "public",
                table: "RefreshTokens",
                type: "character varying(45)",
                maxLength: 45,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UserAgent",
                schema: "public",
                table: "RefreshTokens",
                type: "character varying(400)",
                maxLength: 400,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TwoFactorRecoveryCodes",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CodeHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    UsedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwoFactorRecoveryCodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TwoFactorRecoveryCodes_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorRecoveryCodes_TenantId_UserId",
                schema: "public",
                table: "TwoFactorRecoveryCodes",
                columns: new[] { "TenantId", "UserId" });

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorRecoveryCodes_TenantId_UserId_CodeHash",
                schema: "public",
                table: "TwoFactorRecoveryCodes",
                columns: new[] { "TenantId", "UserId", "CodeHash" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorRecoveryCodes_UserId",
                schema: "public",
                table: "TwoFactorRecoveryCodes",
                column: "UserId");

            migrationBuilder.CreateTable(
                name: "TwoFactorChallenges",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TokenHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ConsumedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwoFactorChallenges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TwoFactorChallenges_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorChallenges_ExpiresAt_ConsumedAt",
                schema: "public",
                table: "TwoFactorChallenges",
                columns: new[] { "ExpiresAt", "ConsumedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorChallenges_TokenHash",
                schema: "public",
                table: "TwoFactorChallenges",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TwoFactorChallenges_UserId",
                schema: "public",
                table: "TwoFactorChallenges",
                column: "UserId");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TwoFactorChallenges",
                schema: "public");

            migrationBuilder.DropTable(
                name: "TwoFactorRecoveryCodes",
                schema: "public");

            migrationBuilder.DropColumn(
                name: "DeviceLabel",
                schema: "public",
                table: "RefreshTokens");

            migrationBuilder.DropColumn(
                name: "IpAddress",
                schema: "public",
                table: "RefreshTokens");

            migrationBuilder.DropColumn(
                name: "UserAgent",
                schema: "public",
                table: "RefreshTokens");

            migrationBuilder.DropColumn(
                name: "TwoFactorEnabled",
                schema: "public",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TwoFactorEnabledAt",
                schema: "public",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TwoFactorPendingSecret",
                schema: "public",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TwoFactorSecret",
                schema: "public",
                table: "Users");
        }
    }
}
