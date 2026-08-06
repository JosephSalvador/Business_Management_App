using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class _20260806_AdoptExplicitPublicSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "public");

            migrationBuilder.RenameTable(
                name: "Users",
                newName: "Users",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "UserRoles",
                newName: "UserRoles",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "UserBranches",
                newName: "UserBranches",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "Tenants",
                newName: "Tenants",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "Roles",
                newName: "Roles",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "RolePermissions",
                newName: "RolePermissions",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "RefreshTokens",
                newName: "RefreshTokens",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "Permissions",
                newName: "Permissions",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "OutboxMessages",
                newName: "OutboxMessages",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "FeatureFlags",
                newName: "FeatureFlags",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "Branches",
                newName: "Branches",
                newSchema: "public");

            migrationBuilder.RenameTable(
                name: "AuditLogs",
                newName: "AuditLogs",
                newSchema: "public");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameTable(
                name: "Users",
                schema: "public",
                newName: "Users");

            migrationBuilder.RenameTable(
                name: "UserRoles",
                schema: "public",
                newName: "UserRoles");

            migrationBuilder.RenameTable(
                name: "UserBranches",
                schema: "public",
                newName: "UserBranches");

            migrationBuilder.RenameTable(
                name: "Tenants",
                schema: "public",
                newName: "Tenants");

            migrationBuilder.RenameTable(
                name: "Roles",
                schema: "public",
                newName: "Roles");

            migrationBuilder.RenameTable(
                name: "RolePermissions",
                schema: "public",
                newName: "RolePermissions");

            migrationBuilder.RenameTable(
                name: "RefreshTokens",
                schema: "public",
                newName: "RefreshTokens");

            migrationBuilder.RenameTable(
                name: "Permissions",
                schema: "public",
                newName: "Permissions");

            migrationBuilder.RenameTable(
                name: "OutboxMessages",
                schema: "public",
                newName: "OutboxMessages");

            migrationBuilder.RenameTable(
                name: "FeatureFlags",
                schema: "public",
                newName: "FeatureFlags");

            migrationBuilder.RenameTable(
                name: "Branches",
                schema: "public",
                newName: "Branches");

            migrationBuilder.RenameTable(
                name: "AuditLogs",
                schema: "public",
                newName: "AuditLogs");
        }
    }
}
