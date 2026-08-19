using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Purchasing.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Purchasing.Queries;

// ── List Suppliers ─────────────────────────────────────────────────
public sealed record ListSuppliersQuery(int Page, int PageSize, string? Search = null)
    : IRequest<Result<PagedResult<SupplierDto>>>;

public sealed class ListSuppliersQueryHandler
    : IRequestHandler<ListSuppliersQuery, Result<PagedResult<SupplierDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierRepository _suppliers;

    public ListSuppliersQueryHandler(ITenantContext tenantContext, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _suppliers = suppliers;
    }

    public async Task<Result<PagedResult<SupplierDto>>> Handle(
        ListSuppliersQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _suppliers.ListAsync(tenantId, query.Page, query.PageSize, query.Search, cancellationToken);
        var total = await _suppliers.CountAsync(tenantId, query.Search, cancellationToken);

        return Result.Success(new PagedResult<SupplierDto>(
            items.Select(PurchasingMappers.ToDto).ToList(), query.Page, query.PageSize, total));
    }
}

// ── Get Supplier ───────────────────────────────────────────────────
public sealed record GetSupplierQuery(Guid Id)
    : IRequest<Result<SupplierDto>>;

public sealed class GetSupplierQueryHandler
    : IRequestHandler<GetSupplierQuery, Result<SupplierDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierRepository _suppliers;

    public GetSupplierQueryHandler(ITenantContext tenantContext, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierDto>> Handle(
        GetSupplierQuery query, CancellationToken cancellationToken)
    {
        var supplier = await _suppliers.GetByIdAsync(_tenantContext.TenantId, query.Id, cancellationToken);
        if (supplier is null) return Error.NotFound("Supplier not found.");
        return Result.Success(PurchasingMappers.ToDto(supplier));
    }
}

// ── Update Supplier ────────────────────────────────────────────────
public sealed record UpdateSupplierCommand(
    Guid Id, string Name, string? ContactName, string? Email, string? Phone,
    string? Address, string? Tin, string? Notes, bool IsActive)
    : IRequest<Result<SupplierDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateSupplierCommandHandler
    : IRequestHandler<UpdateSupplierCommand, Result<SupplierDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierRepository _suppliers;

    public UpdateSupplierCommandHandler(ITenantContext tenantContext, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierDto>> Handle(
        UpdateSupplierCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var supplier = await _suppliers.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (supplier is null) return Error.NotFound("Supplier not found.");

        supplier.UpdateDetails(
            command.ContactName, command.Email, command.Phone,
            command.Address, command.Tin, command.Notes);

        if (command.IsActive && !supplier.IsActive) supplier.Activate();
        else if (!command.IsActive && supplier.IsActive) supplier.Deactivate();

        await _suppliers.UpdateAsync(supplier, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(supplier));
    }
}

// ── List Purchase Orders ───────────────────────────────────────────
public sealed record ListPurchaseOrdersQuery(int Page, int PageSize)
    : IRequest<Result<PagedResult<PurchaseOrderSummaryDto>>>;

public sealed class ListPurchaseOrdersQueryHandler
    : IRequestHandler<ListPurchaseOrdersQuery, Result<PagedResult<PurchaseOrderSummaryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;

    public ListPurchaseOrdersQueryHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
    }

    public async Task<Result<PagedResult<PurchaseOrderSummaryDto>>> Handle(
        ListPurchaseOrdersQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _purchaseOrders.ListAsync(tenantId, query.Page, query.PageSize, cancellationToken);
        var total = await _purchaseOrders.CountAsync(tenantId, cancellationToken);

        var summaries = new List<PurchaseOrderSummaryDto>();
        foreach (var o in items)
        {
            var supplier = await _suppliers.GetByIdAsync(tenantId, o.SupplierId, cancellationToken);
            var warehouse = await _warehouses.GetByIdAsync(tenantId, o.WarehouseId, cancellationToken);
            summaries.Add(PurchasingMappers.ToSummary(o, supplier?.Name ?? "Unknown", warehouse?.Name ?? "Unknown"));
        }

        return Result.Success(new PagedResult<PurchaseOrderSummaryDto>(
            summaries, query.Page, query.PageSize, total));
    }
}

// ── Get Purchase Order ─────────────────────────────────────────────
public sealed record GetPurchaseOrderQuery(Guid Id)
    : IRequest<Result<PurchaseOrderDto>>;

public sealed class GetPurchaseOrderQueryHandler
    : IRequestHandler<GetPurchaseOrderQuery, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;

    public GetPurchaseOrderQueryHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        GetPurchaseOrderQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var order = await _purchaseOrders.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        var supplier = await _suppliers.GetByIdAsync(tenantId, order.SupplierId, cancellationToken);
        var warehouse = await _warehouses.GetByIdAsync(tenantId, order.WarehouseId, cancellationToken);
        var lines = order.Lines.Select(l => new PurchaseOrderLineDto(
            l.Id, l.ProductId, string.Empty, l.Quantity, l.UnitPrice, l.LineTotal)).ToList();

        return Result.Success(PurchasingMappers.ToDto(
            order, supplier?.Name ?? "Unknown", warehouse?.Name ?? "Unknown", lines));
    }
}

// ── List Supplier Bills ────────────────────────────────────────────
public sealed record ListSupplierBillsQuery(int Page, int PageSize)
    : IRequest<Result<PagedResult<SupplierBillDto>>>;

public sealed class ListSupplierBillsQueryHandler
    : IRequestHandler<ListSupplierBillsQuery, Result<PagedResult<SupplierBillDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierBillRepository _bills;
    private readonly ISupplierRepository _suppliers;

    public ListSupplierBillsQueryHandler(
        ITenantContext tenantContext, ISupplierBillRepository bills, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _bills = bills;
        _suppliers = suppliers;
    }

    public async Task<Result<PagedResult<SupplierBillDto>>> Handle(
        ListSupplierBillsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _bills.ListAsync(tenantId, query.Page, query.PageSize, cancellationToken);
        var total = await _bills.CountAsync(tenantId, cancellationToken);

        var dtos = new List<SupplierBillDto>();
        foreach (var b in items)
        {
            var supplier = await _suppliers.GetByIdAsync(tenantId, b.SupplierId, cancellationToken);
            dtos.Add(PurchasingMappers.ToDto(b, supplier?.Name ?? "Unknown"));
        }

        return Result.Success(new PagedResult<SupplierBillDto>(
            dtos, query.Page, query.PageSize, total));
    }
}

// ── Get Supplier Bill ──────────────────────────────────────────────
public sealed record GetSupplierBillQuery(Guid Id)
    : IRequest<Result<SupplierBillDto>>;

public sealed class GetSupplierBillQueryHandler
    : IRequestHandler<GetSupplierBillQuery, Result<SupplierBillDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierBillRepository _bills;
    private readonly ISupplierRepository _suppliers;

    public GetSupplierBillQueryHandler(
        ITenantContext tenantContext, ISupplierBillRepository bills, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _bills = bills;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierBillDto>> Handle(
        GetSupplierBillQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var bill = await _bills.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (bill is null) return Error.NotFound("Supplier bill not found.");

        var supplier = await _suppliers.GetByIdAsync(tenantId, bill.SupplierId, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(bill, supplier?.Name ?? "Unknown"));
    }
}
