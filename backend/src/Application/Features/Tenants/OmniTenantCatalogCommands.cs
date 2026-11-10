using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ListTenantProductsAdminQuery(
    Guid TenantId,
    string? Search = null,
    bool LowStockOnly = false,
    int Page = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<OmniProductDto>>>;

public sealed class ListTenantProductsAdminQueryHandler : IRequestHandler<ListTenantProductsAdminQuery, Result<PagedResult<OmniProductDto>>>
{
    private readonly IOmniTenantCatalogRepository _catalog;

    public ListTenantProductsAdminQueryHandler(IOmniTenantCatalogRepository catalog) => _catalog = catalog;

    public async Task<Result<PagedResult<OmniProductDto>>> Handle(
        ListTenantProductsAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _catalog.ListTenantProductsAsync(
            request.TenantId, request.Search, request.LowStockOnly, request.Page, request.PageSize, cancellationToken);
        return Result.Success(result);
    }
}

public sealed record UpdateTenantProductAdminCommand(
    Guid TenantId,
    Guid ProductId,
    string Name,
    string? Barcode,
    decimal BuyingPrice,
    decimal SellingPrice,
    string? Category,
    bool IsActive) : IRequest<Result<OmniProductDto>>;

public sealed class UpdateTenantProductAdminCommandHandler : IRequestHandler<UpdateTenantProductAdminCommand, Result<OmniProductDto>>
{
    private readonly IOmniTenantCatalogRepository _catalog;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantProductAdminCommandHandler(
        IOmniTenantCatalogRepository catalog,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _catalog = catalog;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<OmniProductDto>> Handle(
        UpdateTenantProductAdminCommand request, CancellationToken cancellationToken)
    {
        var product = await _catalog.GetProductByIdAsync(request.TenantId, request.ProductId, cancellationToken);
        if (product is null)
        {
            return Error.NotFound($"Product {request.ProductId} was not found.");
        }

        product.Update(
            request.Name,
            product.Sku,
            request.Barcode,
            request.BuyingPrice,
            request.SellingPrice,
            product.Description,
            product.CategoryId,
            product.UnitOfMeasureId,
            product.BrandId,
            product.IsService);

        if (request.IsActive && !product.IsActive)
        {
            product.Activate();
        }
        else if (!request.IsActive && product.IsActive)
        {
            product.Deactivate();
        }

        await _catalog.UpdateProductAsync(product, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.UpdateProduct",
                "Product",
                product.Id,
                $"Updated by Platform Operator: {request.Name}"),
            cancellationToken);

        return Result.Success(new OmniProductDto(
            product.Id,
            product.Name,
            product.Barcode,
            product.Sku,
            Category: request.Category,
            Unit: "pcs",
            request.BuyingPrice,
            request.SellingPrice,
            CurrentStock: 0,
            LowStockThreshold: 5,
            StockStatus: "Normal",
            product.IsActive));
    }
}

public sealed record AdjustTenantStockAdminCommand(
    Guid TenantId,
    Guid ProductId,
    decimal NewStockQuantity,
    string Reason) : IRequest<Result>;

public sealed class AdjustTenantStockAdminCommandHandler : IRequestHandler<AdjustTenantStockAdminCommand, Result>
{
    private readonly IOmniTenantCatalogRepository _catalog;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public AdjustTenantStockAdminCommandHandler(
        IOmniTenantCatalogRepository catalog,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _catalog = catalog;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        AdjustTenantStockAdminCommand request, CancellationToken cancellationToken)
    {
        var product = await _catalog.GetProductByIdAsync(request.TenantId, request.ProductId, cancellationToken);
        if (product is null)
        {
            return Error.NotFound($"Product {request.ProductId} was not found.");
        }

        await _catalog.AdjustProductStockAsync(
            request.TenantId,
            request.ProductId,
            request.NewStockQuantity,
            request.Reason,
            _tenantContext.UserId,
            cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.AdjustStock",
                "Product",
                product.Id,
                $"Stock adjusted to {request.NewStockQuantity} by Platform Operator. Reason: {request.Reason}"),
            cancellationToken);

        return Result.Success();
    }
}

public sealed record SeedStarterCatalogCommand(
    Guid TenantId,
    string TemplateType) : IRequest<Result>;

public sealed class SeedStarterCatalogCommandHandler : IRequestHandler<SeedStarterCatalogCommand, Result>
{
    private readonly IOmniTenantCatalogRepository _catalog;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public SeedStarterCatalogCommandHandler(
        IOmniTenantCatalogRepository catalog,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _catalog = catalog;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        SeedStarterCatalogCommand request, CancellationToken cancellationToken)
    {
        await _catalog.SeedStarterCatalogAsync(
            request.TenantId, request.TemplateType, _tenantContext.UserId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.SeedStarterCatalog",
                "Tenant",
                request.TenantId,
                $"Seeded starter catalog template: {request.TemplateType}"),
            cancellationToken);

        return Result.Success();
    }
}
