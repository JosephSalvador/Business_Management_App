using System.Security.Cryptography;
using System.Text;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using Fluid;
using Microsoft.Extensions.Caching.Memory;

namespace BusinessOS.Infrastructure.Services;

public sealed record TemplateThemeContext(
    string PrimaryHex,
    string SecondaryHex,
    string? LogoUrl,
    bool ShowLogo,
    string? FooterNotes);

public sealed class InvoiceTemplateRenderService : IDocumentTemplateRenderService
{
    private static readonly FluidParser Parser = new();
    private static readonly TemplateOptions Options;

    static InvoiceTemplateRenderService()
    {
        Options = new TemplateOptions();
        var strategy = Options.MemberAccessStrategy;

        // Whitelist isolated flat data properties from CustomerInvoiceDto, DeliveryNoteDto, and TenantOrganizationDto
        strategy.Register<CustomerInvoiceDto>();
        strategy.Register<CustomerInvoiceLineDto>();
        strategy.Register<DeliveryNoteDto>();
        strategy.Register<DeliveryNoteItemDto>();
        strategy.Register<TenantOrganizationDto>();
        strategy.Register<TemplateThemeContext>();
    }

    private readonly IMemoryCache _cache;
    private readonly ITenantDocumentConfigurationRepository _configs;
    private readonly IDocumentTemplateRepository _templates;

    public InvoiceTemplateRenderService(
        IMemoryCache cache,
        ITenantDocumentConfigurationRepository configs,
        IDocumentTemplateRepository templates)
    {
        _cache = cache;
        _configs = configs;
        _templates = templates;
    }

    public async Task<string> RenderInvoiceHtmlAsync(
        Guid tenantId,
        CustomerInvoiceDto invoice,
        TenantOrganizationDto organization,
        CancellationToken cancellationToken = default)
    {
        var config = await _configs.GetAsync(tenantId, DocumentType.Invoice, cancellationToken);
        var (layout, templateId) = await ResolveLayoutAsync(config, DocumentType.Invoice, cancellationToken);

        var theme = new TemplateThemeContext(
            PrimaryHex: config?.ThemePrimaryHex ?? "#0F172A",
            SecondaryHex: config?.ThemeSecondaryHex ?? "#64748B",
            LogoUrl: config?.LogoUrl ?? organization.LogoBase64,
            ShowLogo: config?.ShowLogo ?? true,
            FooterNotes: config?.FooterNotes ?? organization.InvoiceTerms);

        var fluidTemplate = GetOrParseTemplate(templateId, layout);

        var context = new TemplateContext(Options);
        context.SetValue("invoice", invoice);
        context.SetValue("organization", organization);
        context.SetValue("theme", theme);

        return await fluidTemplate.RenderAsync(context);
    }

    public async Task<string> RenderDeliveryNoteHtmlAsync(
        Guid tenantId,
        DeliveryNoteDto deliveryNote,
        TenantOrganizationDto organization,
        CancellationToken cancellationToken = default)
    {
        var config = await _configs.GetAsync(tenantId, DocumentType.DeliveryNote, cancellationToken);
        var (layout, templateId) = await ResolveLayoutAsync(config, DocumentType.DeliveryNote, cancellationToken);

        var theme = new TemplateThemeContext(
            PrimaryHex: config?.ThemePrimaryHex ?? "#0F172A",
            SecondaryHex: config?.ThemeSecondaryHex ?? "#64748B",
            LogoUrl: config?.LogoUrl ?? organization.LogoBase64,
            ShowLogo: config?.ShowLogo ?? true,
            FooterNotes: config?.FooterNotes);

        var fluidTemplate = GetOrParseTemplate(templateId, layout);

        var context = new TemplateContext(Options);
        context.SetValue("delivery_note", deliveryNote);
        context.SetValue("organization", organization);
        context.SetValue("theme", theme);

        return await fluidTemplate.RenderAsync(context);
    }

    public async Task<string> RenderPreviewHtmlAsync(
        string liquidLayout,
        DocumentType documentType,
        string? themePrimaryHex,
        string? logoUrl,
        CancellationToken cancellationToken = default)
    {
        var sampleOrg = new TenantOrganizationDto(
            Id: Guid.NewGuid(),
            Name: "Acme Enterprises Ltd",
            Email: "info@acme.co.tz",
            Phone: "+255 700 000 000",
            Address: "Plot 42, Samora Avenue, Dar es Salaam",
            Currency: "TZS",
            CountryCode: "TZ",
            Tin: "123-456-789",
            LogoBase64: logoUrl,
            BankName: "CRDB Bank",
            BankAccountName: "Acme Enterprises Ltd",
            BankAccountNumber: "0150123456789",
            InvoiceTerms: "Payment is due within 30 days of invoice date.");

        var theme = new TemplateThemeContext(
            PrimaryHex: themePrimaryHex ?? "#0F172A",
            SecondaryHex: "#64748B",
            LogoUrl: logoUrl,
            ShowLogo: true,
            FooterNotes: "Thank you for your business!");

        var fluidTemplate = GetOrParseTemplate("preview", liquidLayout);
        var context = new TemplateContext(Options);
        context.SetValue("organization", sampleOrg);
        context.SetValue("theme", theme);

        if (documentType == DocumentType.Invoice)
        {
            var sampleInvoice = new CustomerInvoiceDto(
                Id: Guid.NewGuid(),
                Number: "INV-2026-0001",
                CustomerId: Guid.NewGuid(),
                CustomerName: "Mlimani Holdings Ltd",
                Currency: "TZS",
                IssueDate: DateTime.UtcNow,
                DueDate: DateTime.UtcNow.AddDays(30),
                Notes: "Sample invoice preview notes",
                Status: CustomerInvoiceStatus.Unpaid,
                Subtotal: 1000000m,
                TaxAmount: 180000m,
                TotalAmount: 118000m,
                AmountPaid: 0m,
                BalanceDue: 118000m,
                PaymentMethod: null,
                PaymentReference: null,
                PaidAtUtc: null,
                VoidedAtUtc: null,
                Lines: new List<CustomerInvoiceLineDto>
                {
                    new(Guid.NewGuid(), "Professional Enterprise Consulting", 2m, 400000m, 18m, 800000m, 144000m, "Hours"),
                    new(Guid.NewGuid(), "Server Setup & Cloud Migration", 1m, 200000m, 18m, 200000m, 36000m, "Units")
                },
                CreatedAt: DateTime.UtcNow);

            context.SetValue("invoice", sampleInvoice);
        }
        else
        {
            var sampleDeliveryNote = new DeliveryNoteDto(
                Id: Guid.NewGuid(),
                Number: "DN-2026-0001",
                InvoiceId: Guid.NewGuid(),
                InvoiceNumber: "INV-2026-0001",
                CustomerId: Guid.NewGuid(),
                CustomerName: "Mlimani Holdings Ltd",
                CustomerAttention: "Mr. Juma",
                CustomerPhone: "+255 712 345 678",
                DeliveryAddress: "Kariakoo, Msimbazi Street",
                IssueDate: DateTime.UtcNow,
                Status: DeliveryNoteStatus.Draft,
                VehicleNumber: "T 123 ABC",
                DriverName: "Rashid Ali",
                DriverPhone: "+255 788 111 222",
                ReceivedByName: null,
                Notes: "Handle with care",
                DispatchedAtUtc: null,
                DeliveredAtUtc: null,
                CancelledAtUtc: null,
                Items: new List<DeliveryNoteItemDto>
                {
                    new(Guid.NewGuid(), null, "High-Grade Construction Cement 50kg", "Bags", 50m, 50m, 0),
                    new(Guid.NewGuid(), null, "Reinforced Steel Bars 12mm", "Pcs", 20m, 20m, 1)
                },
                CreatedAt: DateTime.UtcNow);

            context.SetValue("delivery_note", sampleDeliveryNote);
        }

        return await fluidTemplate.RenderAsync(context);
    }

    private async Task<(string Layout, string TemplateId)> ResolveLayoutAsync(
        TenantDocumentConfiguration? config, DocumentType type, CancellationToken cancellationToken)
    {
        if (config is not null && !string.IsNullOrWhiteSpace(config.CustomLiquidOverride))
        {
            return (config.CustomLiquidOverride, $"custom-{config.Id}");
        }

        if (config is not null && config.ActiveTemplateId != Guid.Empty)
        {
            var active = await _templates.GetByIdAsync(config.ActiveTemplateId, cancellationToken);
            if (active is not null && active.IsActive)
            {
                return (active.LiquidLayout, active.Id.ToString());
            }
        }

        var defaultTemplate = await _templates.GetDefaultAsync(type, cancellationToken);
        if (defaultTemplate is not null)
        {
            return (defaultTemplate.LiquidLayout, defaultTemplate.Id.ToString());
        }

        // Hardcoded minimal fallback layout if DB is not yet seeded
        return (GetFallbackLayout(type), $"fallback-{type}");
    }

    private IFluidTemplate GetOrParseTemplate(string templateId, string layout)
    {
        var layoutHash = ComputeSha256(layout);
        var cacheKey = $"tpl:{templateId}:{layoutHash}";

        if (!_cache.TryGetValue(cacheKey, out IFluidTemplate? fluidTemplate) || fluidTemplate is null)
        {
            if (!Parser.TryParse(layout, out fluidTemplate, out var error))
            {
                throw new InvalidOperationException($"Liquid parsing error in template '{templateId}': {error}");
            }

            _cache.Set(cacheKey, fluidTemplate, new MemoryCacheEntryOptions
            {
                SlidingExpiration = TimeSpan.FromHours(24)
            });
        }

        return fluidTemplate;
    }

    private static string ComputeSha256(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes);
    }

    private static string GetFallbackLayout(DocumentType type)
    {
        if (type == DocumentType.Invoice)
        {
            return @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Invoice {{ invoice.number }}</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; padding: 24px; }
.header { border-bottom: 2px solid {{ theme.primary_hex }}; padding-bottom: 16px; margin-bottom: 24px; }
.title { font-size: 24px; font-weight: bold; color: {{ theme.primary_hex }}; }
table { width: 100%; border-collapse: collapse; margin-top: 16px; }
th { background: #f8fafc; text-align: left; padding: 8px; border-bottom: 2px solid #e2e8f0; }
td { padding: 8px; border-bottom: 1px solid #f1f5f9; }
.total { font-size: 18px; font-weight: bold; text-align: right; margin-top: 16px; }
</style>
</head>
<body>
<div class=""header"">
    <div class=""title"">INVOICE {{ invoice.number }}</div>
    <div>{{ organization.name }}</div>
    <div>Date: {{ invoice.issue_date }}</div>
</div>
<div><strong>Bill To:</strong> {{ invoice.customer_name }}</div>
<table>
<thead><tr><th>Description</th><th>Qty</th><th>Unit Price</th><th>Total</th></tr></thead>
<tbody>
{% for line in invoice.lines %}
<tr>
    <td>{{ line.description }}</td>
    <td>{{ line.quantity }} {{ line.unit_of_measure }}</td>
    <td>{{ line.unit_price }}</td>
    <td>{{ line.line_total }}</td>
</tr>
{% endfor %}
</tbody>
</table>
<div class=""total"">Total: {{ invoice.currency }} {{ invoice.total_amount }}</div>
</body>
</html>";
        }

        return @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Delivery Note {{ delivery_note.number }}</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; padding: 24px; }
.header { border-bottom: 2px solid {{ theme.primary_hex }}; padding-bottom: 16px; margin-bottom: 24px; }
.title { font-size: 24px; font-weight: bold; color: {{ theme.primary_hex }}; }
table { width: 100%; border-collapse: collapse; margin-top: 16px; }
th { background: #f8fafc; text-align: left; padding: 8px; border-bottom: 2px solid #e2e8f0; }
td { padding: 8px; border-bottom: 1px solid #f1f5f9; }
</style>
</head>
<body>
<div class=""header"">
    <div class=""title"">DELIVERY NOTE {{ delivery_note.number }}</div>
    <div>{{ organization.name }}</div>
</div>
<div><strong>Recipient:</strong> {{ delivery_note.customer_name }}</div>
<div><strong>Delivery Address:</strong> {{ delivery_note.delivery_address }}</div>
<div><strong>Driver:</strong> {{ delivery_note.driver_name }} ({{ delivery_note.vehicle_number }})</div>
<table>
<thead><tr><th>Item</th><th>Ordered</th><th>Delivered</th></tr></thead>
<tbody>
{% for item in delivery_note.items %}
<tr>
    <td>{{ item.description }}</td>
    <td>{{ item.quantity_ordered }} {{ item.unit_of_measure }}</td>
    <td>{{ item.quantity_delivered }} {{ item.unit_of_measure }}</td>
</tr>
{% endfor %}
</tbody>
</table>
</body>
</html>";
    }
}
