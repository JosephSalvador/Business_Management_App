using System.Diagnostics;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Infrastructure.Services;
using Microsoft.Extensions.Caching.Memory;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class TemplateRenderServiceTests
{
    private sealed class FakeTemplateRepository : IDocumentTemplateRepository
    {
        private readonly List<DocumentTemplate> _templates = new();

        public FakeTemplateRepository(IEnumerable<DocumentTemplate>? seed = null)
        {
            if (seed != null) _templates.AddRange(seed);
        }

        public Task<DocumentTemplate?> GetByIdAsync(Guid id, CancellationToken ct = default)
            => Task.FromResult(_templates.FirstOrDefault(t => t.Id == id));

        public Task<DocumentTemplate?> GetDefaultAsync(DocumentType type, CancellationToken ct = default)
            => Task.FromResult(_templates.FirstOrDefault(t => t.DocumentType == type && t.IsActive && t.IsDefault));

        public Task<IReadOnlyList<DocumentTemplate>> ListActiveAsync(DocumentType? type = null, CancellationToken ct = default)
        {
            var query = _templates.Where(t => t.IsActive);
            if (type.HasValue) query = query.Where(t => t.DocumentType == type.Value);
            return Task.FromResult<IReadOnlyList<DocumentTemplate>>(query.ToList());
        }

        public Task AddAsync(DocumentTemplate template, CancellationToken ct = default)
        {
            _templates.Add(template);
            return Task.CompletedTask;
        }

        public Task UpdateAsync(DocumentTemplate template, CancellationToken ct = default)
            => Task.CompletedTask;
    }

    private sealed class FakeConfigRepository : ITenantDocumentConfigurationRepository
    {
        private readonly List<TenantDocumentConfiguration> _configs = new();

        public Task<TenantDocumentConfiguration?> GetAsync(Guid tenantId, DocumentType type, CancellationToken ct = default)
            => Task.FromResult(_configs.FirstOrDefault(c => c.TenantId == tenantId && c.DocumentType == type));

        public Task<IReadOnlyList<TenantDocumentConfiguration>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<TenantDocumentConfiguration>>(_configs.Where(c => c.TenantId == tenantId).ToList());

        public Task AddAsync(TenantDocumentConfiguration config, CancellationToken ct = default)
        {
            _configs.Add(config);
            return Task.CompletedTask;
        }

        public Task UpdateAsync(TenantDocumentConfiguration config, CancellationToken ct = default)
            => Task.CompletedTask;
    }

    [Fact]
    public async Task RenderInvoiceHtmlAsync_ExecutesUnder50Milliseconds()
    {
        var cache = new MemoryCache(new MemoryCacheOptions());
        var template = DocumentTemplate.Create(
            name: "Modern Test",
            documentType: DocumentType.Invoice,
            liquidLayout: @"<div style=""color: {{ theme.primary_hex }}"">
                <h1>{{ organization.name }}</h1>
                <p>Invoice #{{ invoice.number }}</p>
                <ul>
                {% for line in invoice.lines %}
                    <li>{{ line.description }}: {{ line.quantity }} x {{ line.unit_price }} = {{ line.line_total }}</li>
                {% endfor %}
                </ul>
                <p>Total: {{ invoice.currency }} {{ invoice.total_amount }}</p>
            </div>",
            isDefault: true);

        var templateRepo = new FakeTemplateRepository(new[] { template });
        var configRepo = new FakeConfigRepository();
        var service = new InvoiceTemplateRenderService(cache, configRepo, templateRepo);

        var tenantId = Guid.NewGuid();
        var invoice = new CustomerInvoiceDto(
            Id: Guid.NewGuid(),
            Number: "INV-2026-9999",
            CustomerId: Guid.NewGuid(),
            CustomerName: "Safari Logistics Ltd",
            Currency: "TZS",
            IssueDate: DateTime.UtcNow,
            DueDate: DateTime.UtcNow.AddDays(14),
            Notes: "Thanks",
            Status: CustomerInvoiceStatus.Unpaid,
            Subtotal: 500000m,
            TaxAmount: 90000m,
            TotalAmount: 590000m,
            AmountPaid: 0m,
            BalanceDue: 590000m,
            PaymentMethod: null,
            PaymentReference: null,
            PaidAtUtc: null,
            VoidedAtUtc: null,
            Lines: new List<CustomerInvoiceLineDto>
            {
                new(Guid.NewGuid(), "Express Freight Transport", 2m, 250000m, 18m, 500000m, 90000m, "Trips")
            },
            CreatedAt: DateTime.UtcNow);

        var org = new TenantOrganizationDto(
            Id: tenantId,
            Name: "Kilimanjaro Express",
            Email: "info@kili.co.tz",
            Phone: "+255711000111",
            Address: "Arusha, Tanzania",
            Currency: "TZS",
            CountryCode: "TZ",
            Tin: "999-888-777");

        // Warm-up parse
        await service.RenderInvoiceHtmlAsync(tenantId, invoice, org);

        // Measure compiled AST execution speed
        var sw = Stopwatch.StartNew();
        var html = await service.RenderInvoiceHtmlAsync(tenantId, invoice, org);
        sw.Stop();

        Assert.True(sw.ElapsedMilliseconds < 50, $"Render took {sw.ElapsedMilliseconds}ms, expected under 50ms");
        Assert.Contains("Kilimanjaro Express", html);
        Assert.Contains("INV-2026-9999", html);
        Assert.Contains("Express Freight Transport", html);
        Assert.Contains("590000", html);
    }

    [Fact]
    public async Task RenderPreviewHtmlAsync_GeneratesSampleDocumentSuccessfully()
    {
        var cache = new MemoryCache(new MemoryCacheOptions());
        var service = new InvoiceTemplateRenderService(cache, new FakeConfigRepository(), new FakeTemplateRepository());

        var layout = @"<div class=""preview"">
            <h2>{{ organization.name }}</h2>
            <span>{{ invoice.number }}</span>
            <span>{{ invoice.customer_name }}</span>
            <span>Total: {{ invoice.total_amount }}</span>
        </div>";

        var html = await service.RenderPreviewHtmlAsync(layout, DocumentType.Invoice, "#10B981", null);

        Assert.Contains("Acme Enterprises Ltd", html);
        Assert.Contains("INV-2026-0001", html);
        Assert.Contains("Mlimani Holdings Ltd", html);
    }

    [Fact]
    public void MinimalPdfGenerator_GeneratesConformingA4AndThermalPdfs()
    {
        var items = new List<(string Description, string Quantity, string Total)>
        {
            ("Premium Cement 50kg", "10 Bags", "TZS 180,000"),
            ("Steel Rods 12mm", "20 Pcs", "TZS 400,000")
        };

        // 1. A4 Document
        var a4Bytes = MinimalPdfGenerator.CreateDocument(
            title: "TAX INVOICE",
            documentNumber: "INV-2026-0001",
            organizationName: "Kilimanjaro Hardware Ltd",
            customerName: "Mbowe Builders",
            totalFormatted: "TZS 580,000",
            items: items,
            isThermal: false,
            primaryHex: "#0F172A");

        Assert.NotNull(a4Bytes);
        Assert.NotEmpty(a4Bytes);
        Assert.StartsWith("%PDF-1.4", System.Text.Encoding.Latin1.GetString(a4Bytes));
        Assert.EndsWith("%%EOF\n", System.Text.Encoding.Latin1.GetString(a4Bytes));

        // 2. Thermal 80mm Document
        var thermalBytes = MinimalPdfGenerator.CreateDocument(
            title: "CASH SALE",
            documentNumber: "INV-2026-0002",
            organizationName: "Quick POS Supermarket",
            customerName: "Walk-in",
            totalFormatted: "TZS 580,000",
            items: items,
            isThermal: true,
            primaryHex: "#0D9488");

        Assert.NotNull(thermalBytes);
        Assert.NotEmpty(thermalBytes);
        Assert.StartsWith("%PDF-1.4", System.Text.Encoding.Latin1.GetString(thermalBytes));
        Assert.EndsWith("%%EOF\n", System.Text.Encoding.Latin1.GetString(thermalBytes));
    }
}
