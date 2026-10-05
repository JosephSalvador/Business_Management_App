using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddReceiptRenderingEngine : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ReceiptLayouts",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    LayoutId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    PaperWidth = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaperHeight = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    Sections = table.Column<JsonDocument>(type: "jsonb", nullable: false),
                    Styling = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceiptLayouts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ReceiptLayouts_Tenants_TenantId",
                        column: x => x.TenantId,
                        principalSchema: "public",
                        principalTable: "Tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ReceiptPrintEvents",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SaleId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    PrintedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PrintedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Type = table.Column<int>(type: "integer", nullable: false),
                    LayoutVersionId = table.Column<Guid>(type: "uuid", nullable: true),
                    DeviceId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Notes = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceiptPrintEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ReceiptPrintEvents_Sales_SaleId",
                        column: x => x.SaleId,
                        principalSchema: "public",
                        principalTable: "Sales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ReceiptPrintEvents_Tenants_TenantId",
                        column: x => x.TenantId,
                        principalSchema: "public",
                        principalTable: "Tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ReceiptMetadata",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SaleId = table.Column<Guid>(type: "uuid", nullable: false),
                    LayoutVersionId = table.Column<Guid>(type: "uuid", nullable: false),
                    BusinessIdentitySnapshot = table.Column<string>(type: "jsonb", nullable: false),
                    FiscalHash = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true),
                    FiscalSignatureAlgorithm = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    CanonicalPayloadHash = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceiptMetadata", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ReceiptMetadata_ReceiptLayouts_LayoutVersionId",
                        column: x => x.LayoutVersionId,
                        principalSchema: "public",
                        principalTable: "ReceiptLayouts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ReceiptMetadata_Sales_SaleId",
                        column: x => x.SaleId,
                        principalSchema: "public",
                        principalTable: "Sales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptLayouts_TenantId_LayoutId_IsActive",
                schema: "public",
                table: "ReceiptLayouts",
                columns: new[] { "TenantId", "LayoutId", "IsActive" },
                filter: "\"IsActive\" = true");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptLayouts_TenantId_LayoutId_Version",
                schema: "public",
                table: "ReceiptLayouts",
                columns: new[] { "TenantId", "LayoutId", "Version" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptMetadata_LayoutVersionId",
                schema: "public",
                table: "ReceiptMetadata",
                column: "LayoutVersionId");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptMetadata_SaleId",
                schema: "public",
                table: "ReceiptMetadata",
                column: "SaleId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptPrintEvents_SaleId_PrintedAt",
                schema: "public",
                table: "ReceiptPrintEvents",
                columns: new[] { "SaleId", "PrintedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptPrintEvents_TenantId_PrintedAt",
                schema: "public",
                table: "ReceiptPrintEvents",
                columns: new[] { "TenantId", "PrintedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ReceiptMetadata",
                schema: "public");

            migrationBuilder.DropTable(
                name: "ReceiptPrintEvents",
                schema: "public");

            migrationBuilder.DropTable(
                name: "ReceiptLayouts",
                schema: "public");
        }
    }
}
