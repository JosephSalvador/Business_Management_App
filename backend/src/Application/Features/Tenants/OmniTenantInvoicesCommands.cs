using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ListTenantInvoicesAdminQuery(
    Guid TenantId,
    string? Search = null,
    string? Status = null,
    int Page = 1,
    int PageSize = 25) : IRequest<Result<PagedResult<OmniInvoiceSummaryDto>>>;

public sealed class ListTenantInvoicesAdminQueryHandler : IRequestHandler<ListTenantInvoicesAdminQuery, Result<PagedResult<OmniInvoiceSummaryDto>>>
{
    private readonly IOmniTenantInvoicesRepository _invoices;

    public ListTenantInvoicesAdminQueryHandler(IOmniTenantInvoicesRepository invoices) => _invoices = invoices;

    public async Task<Result<PagedResult<OmniInvoiceSummaryDto>>> Handle(
        ListTenantInvoicesAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _invoices.ListTenantInvoicesAsync(
            request.TenantId, request.Search, request.Status, request.Page, request.PageSize, cancellationToken);

        return Result.Success(result);
    }
}

public sealed record GetTenantInvoicePreviewAdminQuery(
    Guid TenantId,
    Guid InvoiceId) : IRequest<Result<OmniInvoicePreviewDto>>;

public sealed class GetTenantInvoicePreviewAdminQueryHandler
    : IRequestHandler<GetTenantInvoicePreviewAdminQuery, Result<OmniInvoicePreviewDto>>
{
    private readonly IOmniTenantInvoicesRepository _invoices;
    private readonly ITenantRepository _tenants;
    private readonly ITenantDocumentConfigurationRepository _configs;
    private readonly IDocumentTemplateRepository _templates;
    private readonly IDocumentTemplateRenderService _renderService;

    public GetTenantInvoicePreviewAdminQueryHandler(
        IOmniTenantInvoicesRepository invoices,
        ITenantRepository tenants,
        ITenantDocumentConfigurationRepository configs,
        IDocumentTemplateRepository templates,
        IDocumentTemplateRenderService renderService)
    {
        _invoices = invoices;
        _tenants = tenants;
        _configs = configs;
        _templates = templates;
        _renderService = renderService;
    }

    public async Task<Result<OmniInvoicePreviewDto>> Handle(
        GetTenantInvoicePreviewAdminQuery request, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetInvoiceByIdAsync(request.TenantId, request.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Result<OmniInvoicePreviewDto>.Failure(
                Error.NotFound($"Invoice '{request.InvoiceId}' was not found for tenant '{request.TenantId}'."));
        }

        var org = await _tenants.GetByIdAsync(request.TenantId, cancellationToken);
        var orgDto = org is not null
            ? TenantOrganizationDto.From(org)
            : new TenantOrganizationDto(
                Id: request.TenantId,
                Name: "Business",
                Email: null,
                Phone: null,
                Address: null,
                Currency: invoice.Currency,
                CountryCode: "TZ",
                Tin: null);

        var config = await _configs.GetAsync(request.TenantId, DocumentType.Invoice, cancellationToken);
        DocumentTemplate? template = null;
        if (config is not null)
        {
            template = await _templates.GetByIdAsync(config.ActiveTemplateId, cancellationToken);
        }

        var invoiceDto = CustomerInvoiceMappers.ToDto(invoice);
        var html = await _renderService.RenderInvoiceHtmlAsync(
            request.TenantId, invoiceDto, orgDto, cancellationToken);

        var isThermal = template is not null &&
            (template.Name.Contains("80mm", StringComparison.OrdinalIgnoreCase) ||
             template.Name.Contains("Thermal", StringComparison.OrdinalIgnoreCase));

        return Result<OmniInvoicePreviewDto>.Success(new OmniInvoicePreviewDto(
            Invoice: invoiceDto,
            Organization: orgDto,
            ThemePrimaryHex: config?.ThemePrimaryHex ?? "#0F172A",
            ThemeSecondaryHex: config?.ThemeSecondaryHex ?? "#64748B",
            TemplateName: template?.Name ?? "Modern Minimalist Invoice",
            IsThermal80mm: isThermal,
            RenderedHtml: html));
    }
}

public sealed record UpdateTenantInvoiceStatusAdminCommand(
    Guid TenantId,
    Guid InvoiceId,
    string NewStatus) : IRequest<Result>;

public sealed class UpdateTenantInvoiceStatusAdminCommandHandler : IRequestHandler<UpdateTenantInvoiceStatusAdminCommand, Result>
{
    private readonly IOmniTenantInvoicesRepository _invoices;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantInvoiceStatusAdminCommandHandler(
        IOmniTenantInvoicesRepository invoices,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _invoices = invoices;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        UpdateTenantInvoiceStatusAdminCommand request, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetInvoiceByIdAsync(request.TenantId, request.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Result.Failure(Error.NotFound($"Invoice {request.InvoiceId} was not found."));
        }

        if (!Enum.TryParse<CustomerInvoiceStatus>(request.NewStatus, true, out var newStatusEnum))
        {
            return Result.Failure(Error.Validation("Invalid invoice status."));
        }

        await _invoices.UpdateInvoiceStatusAsync(invoice, newStatusEnum, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.UpdateInvoiceStatus",
                "CustomerInvoice",
                invoice.Id.ToString(),
                $"Invoice status updated to {newStatusEnum} by Platform Operator"),
            cancellationToken);

        return Result.Success();
    }
}
