using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddInventoryOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "BatchId",
                schema: "public",
                table: "StockBalances",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "BatchId",
                schema: "public",
                table: "StockMovements",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "StockBatches",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProductId = table.Column<Guid>(type: "uuid", nullable: false),
                    VariantId = table.Column<Guid>(type: "uuid", nullable: true),
                    BatchNumber = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ManufacturerDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExpiryDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SupplierId = table.Column<Guid>(type: "uuid", nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockBatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StockBatches_ProductVariants_VariantId",
                        column: x => x.VariantId,
                        principalSchema: "public",
                        principalTable: "ProductVariants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockBatches_Products_ProductId",
                        column: x => x.ProductId,
                        principalSchema: "public",
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Transfers",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceWarehouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceLocationId = table.Column<Guid>(type: "uuid", nullable: true),
                    DestinationWarehouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    DestinationLocationId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    ReferenceType = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ReferenceId = table.Column<Guid>(type: "uuid", nullable: true),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelledAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Transfers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Transfers_Warehouses_DestinationWarehouseId",
                        column: x => x.DestinationWarehouseId,
                        principalSchema: "public",
                        principalTable: "Warehouses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Transfers_StockLocations_DestinationLocationId",
                        column: x => x.DestinationLocationId,
                        principalSchema: "public",
                        principalTable: "StockLocations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Transfers_Warehouses_SourceWarehouseId",
                        column: x => x.SourceWarehouseId,
                        principalSchema: "public",
                        principalTable: "Warehouses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Transfers_StockLocations_SourceLocationId",
                        column: x => x.SourceLocationId,
                        principalSchema: "public",
                        principalTable: "StockLocations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockCounts",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    WarehouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    StockLocationId = table.Column<Guid>(type: "uuid", nullable: true),
                    ProductId = table.Column<Guid>(type: "uuid", nullable: false),
                    VariantId = table.Column<Guid>(type: "uuid", nullable: true),
                    CountedQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    SystemQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    Difference = table.Column<decimal>(type: "numeric", nullable: false),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelledAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockCounts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StockCounts_ProductVariants_VariantId",
                        column: x => x.VariantId,
                        principalSchema: "public",
                        principalTable: "ProductVariants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockCounts_Products_ProductId",
                        column: x => x.ProductId,
                        principalSchema: "public",
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockCounts_StockLocations_StockLocationId",
                        column: x => x.StockLocationId,
                        principalSchema: "public",
                        principalTable: "StockLocations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockCounts_Warehouses_WarehouseId",
                        column: x => x.WarehouseId,
                        principalSchema: "public",
                        principalTable: "Warehouses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TransferLines",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TransferId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProductId = table.Column<Guid>(type: "uuid", nullable: false),
                    VariantId = table.Column<Guid>(type: "uuid", nullable: true),
                    Quantity = table.Column<decimal>(type: "numeric", nullable: false),
                    BatchId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TransferLines", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TransferLines_StockBatches_BatchId",
                        column: x => x.BatchId,
                        principalSchema: "public",
                        principalTable: "StockBatches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TransferLines_ProductVariants_VariantId",
                        column: x => x.VariantId,
                        principalSchema: "public",
                        principalTable: "ProductVariants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TransferLines_Products_ProductId",
                        column: x => x.ProductId,
                        principalSchema: "public",
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TransferLines_Transfers_TransferId",
                        column: x => x.TransferId,
                        principalSchema: "public",
                        principalTable: "Transfers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StockBatches_TenantId",
                schema: "public",
                table: "StockBatches",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_StockBatches_TenantId_ProductId_BatchNumber",
                schema: "public",
                table: "StockBatches",
                columns: new[] { "TenantId", "ProductId", "BatchNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockBatches_VariantId",
                schema: "public",
                table: "StockBatches",
                column: "VariantId");

            migrationBuilder.CreateIndex(
                name: "IX_StockBalances_BatchId",
                schema: "public",
                table: "StockBalances",
                column: "BatchId");

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_ProductId",
                schema: "public",
                table: "StockCounts",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_StockLocationId",
                schema: "public",
                table: "StockCounts",
                column: "StockLocationId");

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_TenantId",
                schema: "public",
                table: "StockCounts",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_TenantId_WarehouseId_ProductId",
                schema: "public",
                table: "StockCounts",
                columns: new[] { "TenantId", "WarehouseId", "ProductId" });

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_VariantId",
                schema: "public",
                table: "StockCounts",
                column: "VariantId");

            migrationBuilder.CreateIndex(
                name: "IX_StockCounts_WarehouseId",
                schema: "public",
                table: "StockCounts",
                column: "WarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_StockMovements_BatchId",
                schema: "public",
                table: "StockMovements",
                column: "BatchId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_DestinationLocationId",
                schema: "public",
                table: "Transfers",
                column: "DestinationLocationId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_DestinationWarehouseId",
                schema: "public",
                table: "Transfers",
                column: "DestinationWarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_SourceLocationId",
                schema: "public",
                table: "Transfers",
                column: "SourceLocationId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_SourceWarehouseId",
                schema: "public",
                table: "Transfers",
                column: "SourceWarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_TenantId",
                schema: "public",
                table: "Transfers",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_Transfers_TenantId_SourceWarehouseId_DestinationWarehouseId",
                schema: "public",
                table: "Transfers",
                columns: new[] { "TenantId", "SourceWarehouseId", "DestinationWarehouseId" });

            migrationBuilder.CreateIndex(
                name: "IX_TransferLines_BatchId",
                schema: "public",
                table: "TransferLines",
                column: "BatchId");

            migrationBuilder.CreateIndex(
                name: "IX_TransferLines_ProductId",
                schema: "public",
                table: "TransferLines",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_TransferLines_TransferId",
                schema: "public",
                table: "TransferLines",
                column: "TransferId");

            migrationBuilder.CreateIndex(
                name: "IX_TransferLines_VariantId",
                schema: "public",
                table: "TransferLines",
                column: "VariantId");

            migrationBuilder.AddForeignKey(
                name: "FK_StockBalances_StockBatches_BatchId",
                schema: "public",
                table: "StockBalances",
                column: "BatchId",
                principalSchema: "public",
                principalTable: "StockBatches",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StockMovements_StockBatches_BatchId",
                schema: "public",
                table: "StockMovements",
                column: "BatchId",
                principalSchema: "public",
                principalTable: "StockBatches",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_StockBalances_StockBatches_BatchId",
                schema: "public",
                table: "StockBalances");

            migrationBuilder.DropForeignKey(
                name: "FK_StockMovements_StockBatches_BatchId",
                schema: "public",
                table: "StockMovements");

            migrationBuilder.DropForeignKey(
                name: "FK_StockBatches_ProductVariants_VariantId",
                schema: "public",
                table: "StockBatches");

            migrationBuilder.DropForeignKey(
                name: "FK_StockBatches_Products_ProductId",
                schema: "public",
                table: "StockBatches");

            migrationBuilder.DropForeignKey(
                name: "FK_StockCounts_ProductVariants_VariantId",
                schema: "public",
                table: "StockCounts");

            migrationBuilder.DropForeignKey(
                name: "FK_StockCounts_Products_ProductId",
                schema: "public",
                table: "StockCounts");

            migrationBuilder.DropForeignKey(
                name: "FK_StockCounts_StockLocations_StockLocationId",
                schema: "public",
                table: "StockCounts");

            migrationBuilder.DropForeignKey(
                name: "FK_StockCounts_Warehouses_WarehouseId",
                schema: "public",
                table: "StockCounts");

            migrationBuilder.DropForeignKey(
                name: "FK_Transfers_Warehouses_DestinationWarehouseId",
                schema: "public",
                table: "Transfers");

            migrationBuilder.DropForeignKey(
                name: "FK_Transfers_StockLocations_DestinationLocationId",
                schema: "public",
                table: "Transfers");

            migrationBuilder.DropForeignKey(
                name: "FK_Transfers_Warehouses_SourceWarehouseId",
                schema: "public",
                table: "Transfers");

            migrationBuilder.DropForeignKey(
                name: "FK_Transfers_StockLocations_SourceLocationId",
                schema: "public",
                table: "Transfers");

            migrationBuilder.DropForeignKey(
                name: "FK_TransferLines_StockBatches_BatchId",
                schema: "public",
                table: "TransferLines");

            migrationBuilder.DropForeignKey(
                name: "FK_TransferLines_ProductVariants_VariantId",
                schema: "public",
                table: "TransferLines");

            migrationBuilder.DropForeignKey(
                name: "FK_TransferLines_Products_ProductId",
                schema: "public",
                table: "TransferLines");

            migrationBuilder.DropForeignKey(
                name: "FK_TransferLines_Transfers_TransferId",
                schema: "public",
                table: "TransferLines");

            migrationBuilder.DropTable(
                name: "StockBatches",
                schema: "public");

            migrationBuilder.DropTable(
                name: "StockCounts",
                schema: "public");

            migrationBuilder.DropTable(
                name: "TransferLines",
                schema: "public");

            migrationBuilder.DropTable(
                name: "Transfers",
                schema: "public");

            migrationBuilder.DropIndex(
                name: "IX_StockBalances_BatchId",
                schema: "public",
                table: "StockBalances");

            migrationBuilder.DropIndex(
                name: "IX_StockMovements_BatchId",
                schema: "public",
                table: "StockMovements");

            migrationBuilder.DropColumn(
                name: "BatchId",
                schema: "public",
                table: "StockBalances");

            migrationBuilder.DropColumn(
                name: "BatchId",
                schema: "public",
                table: "StockMovements");
        }
    }
}
