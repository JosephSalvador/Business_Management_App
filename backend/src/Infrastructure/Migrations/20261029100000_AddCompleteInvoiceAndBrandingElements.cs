using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BusinessOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCompleteInvoiceAndBrandingElements : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Tenant branding & payment instructions
            migrationBuilder.AddColumn<string>(
                name: "LogoBase64",
                schema: "public",
                table: "Tenants",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankName",
                schema: "public",
                table: "Tenants",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankAccountName",
                schema: "public",
                table: "Tenants",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankAccountNumber",
                schema: "public",
                table: "Tenants",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankBranchOrSwift",
                schema: "public",
                table: "Tenants",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MobileMoneyDetails",
                schema: "public",
                table: "Tenants",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "InvoiceTerms",
                schema: "public",
                table: "Tenants",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AuthorizedSignatoryName",
                schema: "public",
                table: "Tenants",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AuthorizedSignatoryTitle",
                schema: "public",
                table: "Tenants",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            // CustomerInvoices universal elements
            migrationBuilder.AddColumn<string>(
                name: "DocumentTitle",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "INVOICE");

            migrationBuilder.AddColumn<string>(
                name: "ReferenceNumber",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentTerms",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerAttention",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerPhone",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerEmail",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(320)",
                maxLength: 320,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerAddress",
                schema: "public",
                table: "CustomerInvoices",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerTin",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "DiscountAmount",
                schema: "public",
                table: "CustomerInvoices",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "PaymentInstructions",
                schema: "public",
                table: "CustomerInvoices",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AuthorizedSignatoryName",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AuthorizedSignatoryTitle",
                schema: "public",
                table: "CustomerInvoices",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            // CustomerInvoiceLines universal elements
            migrationBuilder.AddColumn<string>(
                name: "UnitOfMeasure",
                schema: "public",
                table: "CustomerInvoiceLines",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "Pcs");

            migrationBuilder.AddColumn<decimal>(
                name: "DiscountAmount",
                schema: "public",
                table: "CustomerInvoiceLines",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "UnitOfMeasure", schema: "public", table: "CustomerInvoiceLines");
            migrationBuilder.DropColumn(name: "DiscountAmount", schema: "public", table: "CustomerInvoiceLines");

            migrationBuilder.DropColumn(name: "DocumentTitle", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "ReferenceNumber", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "PaymentTerms", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "CustomerAttention", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "CustomerPhone", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "CustomerEmail", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "CustomerAddress", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "CustomerTin", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "DiscountAmount", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "PaymentInstructions", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "AuthorizedSignatoryName", schema: "public", table: "CustomerInvoices");
            migrationBuilder.DropColumn(name: "AuthorizedSignatoryTitle", schema: "public", table: "CustomerInvoices");

            migrationBuilder.DropColumn(name: "LogoBase64", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "BankName", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "BankAccountName", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "BankAccountNumber", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "BankBranchOrSwift", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "MobileMoneyDetails", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "InvoiceTerms", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "AuthorizedSignatoryName", schema: "public", table: "Tenants");
            migrationBuilder.DropColumn(name: "AuthorizedSignatoryTitle", schema: "public", table: "Tenants");
        }
    }
}
