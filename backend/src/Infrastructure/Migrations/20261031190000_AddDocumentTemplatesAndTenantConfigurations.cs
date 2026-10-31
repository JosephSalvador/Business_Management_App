using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddDocumentTemplatesAndTenantConfigurations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DocumentTemplates",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DocumentType = table.Column<int>(type: "integer", nullable: false),
                    LiquidLayout = table.Column<string>(type: "text", nullable: false),
                    ThumbnailBase64 = table.Column<string>(type: "text", nullable: true),
                    EngineVersion = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    IsDefault = table.Column<bool>(type: "boolean", nullable: false),
                    DisplayOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentTemplates", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TenantDocumentConfigurations",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    DocumentType = table.Column<int>(type: "integer", nullable: false),
                    ActiveTemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    CustomLiquidOverride = table.Column<string>(type: "text", nullable: true),
                    ThemePrimaryHex = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    ThemeSecondaryHex = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    LogoUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ShowLogo = table.Column<bool>(type: "boolean", nullable: false),
                    FooterNotes = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TenantDocumentConfigurations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TenantDocumentConfigurations_DocumentTemplates_ActiveTemplateId",
                        column: x => x.ActiveTemplateId,
                        principalSchema: "public",
                        principalTable: "DocumentTemplates",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentTemplates_DocumentType_IsActive_DisplayOrder",
                schema: "public",
                table: "DocumentTemplates",
                columns: new[] { "DocumentType", "IsActive", "DisplayOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_TenantDocumentConfigurations_ActiveTemplateId",
                schema: "public",
                table: "TenantDocumentConfigurations",
                column: "ActiveTemplateId");

            migrationBuilder.CreateIndex(
                name: "IX_TenantDocumentConfigurations_TenantId_DocumentType",
                schema: "public",
                table: "TenantDocumentConfigurations",
                columns: new[] { "TenantId", "DocumentType" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TenantDocumentConfigurations",
                schema: "public");

            migrationBuilder.DropTable(
                name: "DocumentTemplates",
                schema: "public");
        }
    }
}
