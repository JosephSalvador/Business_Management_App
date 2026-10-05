using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Receipts.Queries;

/// <summary>
/// Lists all receipt layouts (active and inactive versions) for the current tenant.
/// </summary>
public sealed record ListReceiptLayoutsQuery : IRequest<Result<IReadOnlyList<ReceiptLayoutDto>>>;

public sealed class ListReceiptLayoutsQueryHandler : IRequestHandler<ListReceiptLayoutsQuery, Result<IReadOnlyList<ReceiptLayoutDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReceiptLayoutRepository _layouts;

    public ListReceiptLayoutsQueryHandler(
        ITenantContext tenantContext,
        IReceiptLayoutRepository layouts)
    {
        _tenantContext = tenantContext;
        _layouts = layouts;
    }

    public async Task<Result<IReadOnlyList<ReceiptLayoutDto>>> Handle(
        ListReceiptLayoutsQuery request, CancellationToken cancellationToken)
    {
        var layouts = await _layouts.ListAsync(_tenantContext.TenantId, cancellationToken);

        return layouts.Select(l => new ReceiptLayoutDto(
            l.Id,
            l.LayoutId,
            l.Version,
            l.PaperWidth,
            l.PaperHeight,
            l.IsActive,
            l.Sections.RootElement.GetRawText(),
            l.Styling?.RootElement.GetRawText())).ToList();
    }
}

/// <summary>
/// DTO for receipt layout listing.
/// </summary>
public sealed record ReceiptLayoutDto(
    Guid Id,
    string LayoutId,
    int Version,
    string PaperWidth,
    string? PaperHeight,
    bool IsActive,
    string SectionsJson,
    string? StylingJson);
