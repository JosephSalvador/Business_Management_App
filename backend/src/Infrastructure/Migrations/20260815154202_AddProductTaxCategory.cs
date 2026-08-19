using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddProductTaxCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "TaxCategoryId",
                schema: "public",
                table: "Products",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Products_TaxCategoryId",
                schema: "public",
                table: "Products",
                column: "TaxCategoryId");

            migrationBuilder.AddForeignKey(
                name: "FK_Products_TaxCategories_TaxCategoryId",
                schema: "public",
                table: "Products",
                column: "TaxCategoryId",
                principalSchema: "public",
                principalTable: "TaxCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Products_TaxCategories_TaxCategoryId",
                schema: "public",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_Products_TaxCategoryId",
                schema: "public",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "TaxCategoryId",
                schema: "public",
                table: "Products");
        }
    }
}
