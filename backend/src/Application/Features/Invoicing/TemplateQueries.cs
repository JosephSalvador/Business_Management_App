using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Queries;

// ── List Marketplace Document Templates ─────────────────────────────
public sealed record ListDocumentTemplatesQuery(DocumentType? DocumentType = null)
    : IRequest<Result<IReadOnlyList<DocumentTemplateSummaryDto>>>;

public sealed class ListDocumentTemplatesQueryHandler
    : IRequestHandler<ListDocumentTemplatesQuery, Result<IReadOnlyList<DocumentTemplateSummaryDto>>>
{
    private readonly IDocumentTemplateRepository _templates;

    public ListDocumentTemplatesQueryHandler(IDocumentTemplateRepository templates)
    {
        _templates = templates;
    }

    public async Task<Result<IReadOnlyList<DocumentTemplateSummaryDto>>> Handle(
        ListDocumentTemplatesQuery request, CancellationToken cancellationToken)
    {
        var templates = await _templates.ListActiveAsync(request.DocumentType, cancellationToken);
        var dtos = templates.Select(TemplateMappers.ToSummary).ToList();
        return Result<IReadOnlyList<DocumentTemplateSummaryDto>>.Success(dtos);
    }
}

// ── Get Single Document Template ────────────────────────────────────
public sealed record GetDocumentTemplateQuery(Guid Id)
    : IRequest<Result<DocumentTemplateDto>>;

public sealed class GetDocumentTemplateQueryHandler
    : IRequestHandler<GetDocumentTemplateQuery, Result<DocumentTemplateDto>>
{
    private readonly IDocumentTemplateRepository _templates;

    public GetDocumentTemplateQueryHandler(IDocumentTemplateRepository templates)
    {
        _templates = templates;
    }

    public async Task<Result<DocumentTemplateDto>> Handle(
        GetDocumentTemplateQuery request, CancellationToken cancellationToken)
    {
        var template = await _templates.GetByIdAsync(request.Id, cancellationToken);
        if (template is null)
        {
            return Result<DocumentTemplateDto>.Failure(
                Error.NotFound("TEMPLATE_NOT_FOUND", $"Document template '{request.Id}' was not found."));
        }

        return Result<DocumentTemplateDto>.Success(TemplateMappers.ToDto(template));
    }
}

// ── Get Tenant Document Configurations ──────────────────────────────
public sealed record GetTenantDocumentConfigurationsQuery()
    : IRequest<Result<IReadOnlyList<TenantDocumentConfigurationDto>>>;

public sealed class GetTenantDocumentConfigurationsQueryHandler
    : IRequestHandler<GetTenantDocumentConfigurationsQuery, Result<IReadOnlyList<TenantDocumentConfigurationDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantDocumentConfigurationRepository _configs;
    private readonly IDocumentTemplateRepository _templates;

    public GetTenantDocumentConfigurationsQueryHandler(
        ITenantContext tenantContext,
        ITenantDocumentConfigurationRepository configs,
        IDocumentTemplateRepository templates)
    {
        _tenantContext = tenantContext;
        _configs = configs;
        _templates = templates;
    }

    public async Task<Result<IReadOnlyList<TenantDocumentConfigurationDto>>> Handle(
        GetTenantDocumentConfigurationsQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var configs = await _configs.ListAsync(tenantId, cancellationToken);

        var result = new List<TenantDocumentConfigurationDto>();
        foreach (var c in configs)
        {
            var template = await _templates.GetByIdAsync(c.ActiveTemplateId, cancellationToken);
            result.Add(TemplateMappers.ToDto(c, template?.Name));
        }

        return Result<IReadOnlyList<TenantDocumentConfigurationDto>>.Success(result);
    }
}

// ── Render Invoice HTML ─────────────────────────────────────────────
public sealed record RenderInvoiceHtmlQuery(Guid InvoiceId)
    : IRequest<Result<string>>;

public sealed class RenderInvoiceHtmlQueryHandler
    : IRequestHandler<RenderInvoiceHtmlQuery, Result<string>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;
    private readonly IOrganizationRepository _organizations;
    private readonly IDocumentTemplateRenderService _renderService;

    public RenderInvoiceHtmlQueryHandler(
        ITenantContext tenantContext,
        ICustomerInvoiceRepository invoices,
        IOrganizationRepository organizations,
        IDocumentTemplateRenderService renderService)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
        _organizations = organizations;
        _renderService = renderService;
    }

    public async Task<Result<string>> Handle(
        RenderInvoiceHtmlQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var invoice = await _invoices.GetByIdAsync(tenantId, request.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Result<string>.Failure(
                Error.NotFound("INVOICE_NOT_FOUND", $"Customer invoice '{request.InvoiceId}' was not found."));
        }

        var org = await _organizations.GetByIdAsync(tenantId, cancellationToken);
        var orgDto = org is not null ? TenantOrganizationDto.From(org) : new TenantOrganizationDto(
            Id: tenantId,
            Name: "Business",
            Email: null,
            Phone: null,
            Address: null,
            Currency: invoice.Currency,
            CountryCode: "TZ",
            Tin: null);

        var invoiceDto = CustomerInvoiceMappers.ToDto(invoice);
        var html = await _renderService.RenderInvoiceHtmlAsync(tenantId, invoiceDto, orgDto, cancellationToken);

        return Result<string>.Success(html);
    }
}

// ── Render Delivery Note HTML ───────────────────────────────────────
public sealed record RenderDeliveryNoteHtmlQuery(Guid DeliveryNoteId)
    : IRequest<Result<string>>;

public sealed class RenderDeliveryNoteHtmlQueryHandler
    : IRequestHandler<RenderDeliveryNoteHtmlQuery, Result<string>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;
    private readonly IOrganizationRepository _organizations;
    private readonly IDocumentTemplateRenderService _renderService;

    public RenderDeliveryNoteHtmlQueryHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes,
        IOrganizationRepository organizations,
        IDocumentTemplateRenderService renderService)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
        _organizations = organizations;
        _renderService = renderService;
    }

    public async Task<Result<string>> Handle(
        RenderDeliveryNoteHtmlQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, request.DeliveryNoteId, cancellationToken);
        if (note is null)
        {
            return Result<string>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{request.DeliveryNoteId}' was not found."));
        }

        var org = await _organizations.GetByIdAsync(tenantId, cancellationToken);
        var orgDto = org is not null ? TenantOrganizationDto.From(org) : new TenantOrganizationDto(
            Id: tenantId,
            Name: "Business",
            Email: null,
            Phone: null,
            Address: null,
            Currency: "TZS",
            CountryCode: "TZ",
            Tin: null);

        var noteDto = DeliveryNoteMappers.ToDto(note);
        var html = await _renderService.RenderDeliveryNoteHtmlAsync(tenantId, noteDto, orgDto, cancellationToken);

        return Result<string>.Success(html);
    }
}

// ── Preview Document Template HTML ──────────────────────────────────
public sealed record PreviewDocumentTemplateQuery(
    string LiquidLayout,
    DocumentType DocumentType,
    string? ThemePrimaryHex = null,
    string? LogoUrl = null)
    : IRequest<Result<string>>;

public sealed class PreviewDocumentTemplateQueryHandler
    : IRequestHandler<PreviewDocumentTemplateQuery, Result<string>>
{
    private readonly IDocumentTemplateRenderService _renderService;
    private readonly IHtmlSanitizerService _sanitizer;

    public PreviewDocumentTemplateQueryHandler(
        IDocumentTemplateRenderService renderService,
        IHtmlSanitizerService sanitizer)
    {
        _renderService = renderService;
        _sanitizer = sanitizer;
    }

    public async Task<Result<string>> Handle(
        PreviewDocumentTemplateQuery request, CancellationToken cancellationToken)
    {
        var sanitizedLayout = _sanitizer.Sanitize(request.LiquidLayout);
        var html = await _renderService.RenderPreviewHtmlAsync(
            sanitizedLayout,
            request.DocumentType,
            request.ThemePrimaryHex,
            request.LogoUrl,
            cancellationToken);

        return Result<string>.Success(html);
    }
}

// ── Render Invoice PDF Binary ────────────────────────────────────────
public sealed record RenderInvoicePdfQuery(Guid InvoiceId, bool IsThermal = false, string? PrimaryHex = null)
    : IRequest<Result<byte[]>>;

public sealed class RenderInvoicePdfQueryHandler
    : IRequestHandler<RenderInvoicePdfQuery, Result<byte[]>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;
    private readonly IOrganizationRepository _organizations;

    public RenderInvoicePdfQueryHandler(
        ITenantContext tenantContext,
        ICustomerInvoiceRepository invoices,
        IOrganizationRepository organizations)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
        _organizations = organizations;
    }

    public async Task<Result<byte[]>> Handle(
        RenderInvoicePdfQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var invoice = await _invoices.GetByIdAsync(tenantId, request.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Result<byte[]>.Failure(
                Error.NotFound("INVOICE_NOT_FOUND", $"Customer invoice '{request.InvoiceId}' was not found."));
        }

        var org = await _organizations.GetByIdAsync(tenantId, cancellationToken);
        var orgName = org?.Name ?? "Business OS";

        var items = invoice.Lines.Select(l => (
            Description: l.Description,
            Quantity: $"{l.Quantity:G29} {l.UnitOfMeasure}",
            Total: $"{invoice.Currency} {l.LineTotal:N2}"
        )).ToList();

        var totalFormatted = $"{invoice.Currency} {invoice.TotalAmount:N2}";

        var pdfBytes = BusinessOS.Infrastructure.Services.MinimalPdfGenerator.CreateDocument(
            title: invoice.DocumentTitle ?? "INVOICE",
            documentNumber: invoice.Number,
            organizationName: orgName,
            customerName: invoice.CustomerName ?? "Walk-in Customer",
            totalFormatted: totalFormatted,
            items: items,
            isThermal: request.IsThermal,
            primaryHex: request.PrimaryHex);

        return Result<byte[]>.Success(pdfBytes);
    }
}

// ── Render Delivery Note PDF Binary ──────────────────────────────────
public sealed record RenderDeliveryNotePdfQuery(Guid DeliveryNoteId, bool IsThermal = false, string? PrimaryHex = null)
    : IRequest<Result<byte[]>>;

public sealed class RenderDeliveryNotePdfQueryHandler
    : IRequestHandler<RenderDeliveryNotePdfQuery, Result<byte[]>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;
    private readonly IOrganizationRepository _organizations;

    public RenderDeliveryNotePdfQueryHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes,
        IOrganizationRepository organizations)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
        _organizations = organizations;
    }

    public async Task<Result<byte[]>> Handle(
        RenderDeliveryNotePdfQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, request.DeliveryNoteId, cancellationToken);
        if (note is null)
        {
            return Result<byte[]>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{request.DeliveryNoteId}' was not found."));
        }

        var org = await _organizations.GetByIdAsync(tenantId, cancellationToken);
        var orgName = org?.Name ?? "Business OS";

        var items = note.Items.Select(i => (
            Description: i.Description,
            Quantity: $"{i.QuantityOrdered:G29} {i.UnitOfMeasure}",
            Total: $"{i.QuantityDelivered:G29} Delivered"
        )).ToList();

        var pdfBytes = BusinessOS.Infrastructure.Services.MinimalPdfGenerator.CreateDocument(
            title: "DELIVERY NOTE",
            documentNumber: note.Number,
            organizationName: orgName,
            customerName: note.CustomerName ?? "Customer",
            totalFormatted: $"{note.Items.Count} items",
            items: items,
            isThermal: request.IsThermal,
            primaryHex: request.PrimaryHex);

        return Result<byte[]>.Success(pdfBytes);
    }
}

