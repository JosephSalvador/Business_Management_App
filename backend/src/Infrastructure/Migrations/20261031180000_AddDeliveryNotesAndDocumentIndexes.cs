using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddDeliveryNotesAndDocumentIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Indexes on CustomerInvoices & CustomerInvoiceLines
            migrationBuilder.CreateIndex(
                name: "IX_CustomerInvoices_TenantId_CreatedAt",
                schema: "public",
                table: "CustomerInvoices",
                columns: new[] { "TenantId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerInvoiceLines_TenantId_CreatedAt",
                schema: "public",
                table: "CustomerInvoiceLines",
                columns: new[] { "TenantId", "CreatedAt" });

            // DeliveryNotes table
            migrationBuilder.CreateTable(
                name: "DeliveryNotes",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Number = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    InvoiceId = table.Column<Guid>(type: "uuid", nullable: true),
                    InvoiceNumber = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    CustomerId = table.Column<Guid>(type: "uuid", nullable: true),
                    CustomerName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CustomerAttention = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CustomerPhone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    DeliveryAddress = table.Column<string>(type: "text", nullable: true),
                    IssueDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    VehicleNumber = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    DriverName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    DriverPhone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    ReceivedByName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    Notes = table.Column<string>(type: "text", nullable: true),
                    DispatchedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeliveredAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelledAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeliveryNotes", x => x.Id);
                });

            // DeliveryNoteItems table
            migrationBuilder.CreateTable(
                name: "DeliveryNoteItems",
                schema: "public",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeliveryNoteId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProductId = table.Column<Guid>(type: "uuid", nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    UnitOfMeasure = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    QuantityOrdered = table.Column<decimal>(type: "numeric(18,4)", nullable: false),
                    QuantityDelivered = table.Column<decimal>(type: "numeric(18,4)", nullable: false),
                    LineIndex = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeliveryNoteItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DeliveryNoteItems_DeliveryNotes_DeliveryNoteId",
                        column: x => x.DeliveryNoteId,
                        principalSchema: "public",
                        principalTable: "DeliveryNotes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // DeliveryNotes Indexes
            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNotes_TenantId_Number",
                schema: "public",
                table: "DeliveryNotes",
                columns: new[] { "TenantId", "Number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNotes_TenantId_CreatedAt",
                schema: "public",
                table: "DeliveryNotes",
                columns: new[] { "TenantId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNotes_TenantId_Status",
                schema: "public",
                table: "DeliveryNotes",
                columns: new[] { "TenantId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNotes_TenantId_InvoiceId",
                schema: "public",
                table: "DeliveryNotes",
                columns: new[] { "TenantId", "InvoiceId" });

            // DeliveryNoteItems Indexes
            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNoteItems_DeliveryNoteId",
                schema: "public",
                table: "DeliveryNoteItems",
                column: "DeliveryNoteId");

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryNoteItems_TenantId_CreatedAt",
                schema: "public",
                table: "DeliveryNoteItems",
                columns: new[] { "TenantId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DeliveryNoteItems",
                schema: "public");

            migrationBuilder.DropTable(
                name: "DeliveryNotes",
                schema: "public");

            migrationBuilder.DropIndex(
                name: "IX_CustomerInvoiceLines_TenantId_CreatedAt",
                schema: "public",
                table: "CustomerInvoiceLines");

            migrationBuilder.DropIndex(
                name: "IX_CustomerInvoices_TenantId_CreatedAt",
                schema: "public",
                table: "CustomerInvoices");
        }
    }
}
