using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ListTenantSalesAdminQuery(
    Guid TenantId,
    string? Search = null,
    DateTime? StartDate = null,
    DateTime? EndDate = null,
    Guid? CashierId = null,
    int Page = 1,
    int PageSize = 25) : IRequest<Result<PagedResult<OmniSaleSummaryDto>>>;

public sealed class ListTenantSalesAdminQueryHandler : IRequestHandler<ListTenantSalesAdminQuery, Result<PagedResult<OmniSaleSummaryDto>>>
{
    private readonly IOmniTenantSalesRepository _sales;

    public ListTenantSalesAdminQueryHandler(IOmniTenantSalesRepository sales) => _sales = sales;

    public async Task<Result<PagedResult<OmniSaleSummaryDto>>> Handle(
        ListTenantSalesAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _sales.ListTenantSalesAsync(
            request.TenantId,
            request.Search,
            request.StartDate,
            request.EndDate,
            request.CashierId,
            request.Page,
            request.PageSize,
            cancellationToken);

        return Result.Success(result);
    }
}

public sealed record GetTenantSaleDetailAdminQuery(
    Guid TenantId,
    Guid SaleId) : IRequest<Result<OmniSaleDetailDto>>;

public sealed class GetTenantSaleDetailAdminQueryHandler : IRequestHandler<GetTenantSaleDetailAdminQuery, Result<OmniSaleDetailDto>>
{
    private readonly IOmniTenantSalesRepository _sales;

    public GetTenantSaleDetailAdminQueryHandler(IOmniTenantSalesRepository sales) => _sales = sales;

    public async Task<Result<OmniSaleDetailDto>> Handle(
        GetTenantSaleDetailAdminQuery request, CancellationToken cancellationToken)
    {
        var detail = await _sales.GetTenantSaleDetailAsync(request.TenantId, request.SaleId, cancellationToken);
        if (detail is null)
        {
            return Error.NotFound($"Sale {request.SaleId} was not found.");
        }

        return Result.Success(detail);
    }
}

public sealed record VoidTenantSaleAdminCommand(
    Guid TenantId,
    Guid SaleId,
    string Reason) : IRequest<Result>;

public sealed class VoidTenantSaleAdminCommandHandler : IRequestHandler<VoidTenantSaleAdminCommand, Result>
{
    private readonly IOmniTenantSalesRepository _sales;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public VoidTenantSaleAdminCommandHandler(
        IOmniTenantSalesRepository sales,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _sales = sales;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        VoidTenantSaleAdminCommand request, CancellationToken cancellationToken)
    {
        var sale = await _sales.GetSaleByIdAsync(request.TenantId, request.SaleId, cancellationToken);
        if (sale is null)
        {
            return Error.NotFound($"Sale {request.SaleId} was not found.");
        }

        await _sales.VoidSaleAsync(sale, request.Reason, _tenantContext.UserId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.VoidSale",
                "Sale",
                sale.Id,
                $"Voided by Platform Operator: {request.Reason}"),
            cancellationToken);

        return Result.Success();
    }
}

public sealed record ListTenantCashSessionsAdminQuery(
    Guid TenantId,
    int Page = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<OmniCashSessionDto>>>;

public sealed class ListTenantCashSessionsAdminQueryHandler : IRequestHandler<ListTenantCashSessionsAdminQuery, Result<PagedResult<OmniCashSessionDto>>>
{
    private readonly IOmniTenantSalesRepository _sales;

    public ListTenantCashSessionsAdminQueryHandler(IOmniTenantSalesRepository sales) => _sales = sales;

    public async Task<Result<PagedResult<OmniCashSessionDto>>> Handle(
        ListTenantCashSessionsAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _sales.ListTenantCashSessionsAsync(
            request.TenantId, request.Page, request.PageSize, cancellationToken);

        return Result.Success(result);
    }
}
