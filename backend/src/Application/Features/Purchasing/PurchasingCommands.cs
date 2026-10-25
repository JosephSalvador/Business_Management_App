using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Purchasing.Commands;

public static class PurchasingMappers
{
    public static SupplierDto ToDto(Supplier s) => new(
        s.Id, s.TenantId, s.Name, s.ContactName, s.Email, s.Phone,
        s.Address, s.Tin, s.Notes, s.IsActive, s.CreatedAt);

    public static PurchaseOrderDto ToDto(
        PurchaseOrder o, string supplierName, string warehouseName,
        IReadOnlyList<PurchaseOrderLineDto> lines) => new(
        o.Id, o.SupplierId, supplierName, o.WarehouseId, warehouseName,
        o.Status, o.Reference, o.ExpectedDate, o.Notes, o.TotalAmount,
        lines, o.SubmittedAt, o.ReceivedAt, o.CancelledAt, o.CreatedAt);

    public static PurchaseOrderSummaryDto ToSummary(
        PurchaseOrder o, string supplierName, string warehouseName) => new(
        o.Id, supplierName, warehouseName, o.Status, o.TotalAmount,
        o.Lines.Count, o.CreatedAt);

    public static SupplierBillDto ToDto(
        SupplierBill b, string supplierName) => new(
        b.Id, b.SupplierId, supplierName, b.PurchaseOrderId,
        b.BillNumber, b.BillDate, b.Status, b.Subtotal, b.TaxAmount,
        b.TotalAmount, b.AmountPaid, b.BalanceDue, b.Notes,
        b.ApprovedAt, b.VoidedAt, b.CreatedAt);

    public static SupplierPaymentDto ToDto(SupplierPayment p) => new(
        p.Id, p.Method, p.Amount, p.Provider, p.Reference,
        p.PhoneNumber, p.CreatedAt);
}

// ── Create Supplier ────────────────────────────────────────────────
public sealed record CreateSupplierCommand(
    string Name, string? ContactName, string? Email, string? Phone,
    string? Address, string? Tin, string? Notes)
    : IRequest<Result<SupplierDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateSupplierCommandHandler
    : IRequestHandler<CreateSupplierCommand, Result<SupplierDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierRepository _suppliers;

    public CreateSupplierCommandHandler(ITenantContext tenantContext, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierDto>> Handle(
        CreateSupplierCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var existing = await _suppliers.ListAsync(tenantId, 1, 1, command.Name, cancellationToken);
        if (existing.Any(s => s.Name.Equals(command.Name, StringComparison.OrdinalIgnoreCase)))
        {
            return Error.Conflict($"A supplier named '{command.Name}' already exists.");
        }

        var supplier = Supplier.Create(
            tenantId, command.Name, command.ContactName, command.Email,
            command.Phone, command.Address, command.Tin, command.Notes);

        await _suppliers.AddAsync(supplier, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(supplier));
    }
}

// ── Create Purchase Order ──────────────────────────────────────────
public sealed record CreatePurchaseOrderCommand(
    Guid SupplierId,
    Guid WarehouseId,
    Guid? BranchId,
    string? Reference,
    DateTime? ExpectedDate,
    string? Notes,
    IReadOnlyList<PurchaseOrderLineInput> Lines)
    : IRequest<Result<PurchaseOrderDto>>, IRequiresTenantAdvisoryLock;

public sealed record PurchaseOrderLineInput(
    Guid ProductId, decimal Quantity, decimal UnitPrice);

public sealed record UpdatePurchaseOrderCommand(
    Guid Id,
    Guid SupplierId,
    Guid WarehouseId,
    Guid? BranchId,
    string? Reference,
    DateTime? ExpectedDate,
    string? Notes,
    IReadOnlyList<PurchaseOrderLineInput> Lines)
    : IRequest<Result<PurchaseOrderDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdatePurchaseOrderCommandHandler
    : IRequestHandler<UpdatePurchaseOrderCommand, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;

    public UpdatePurchaseOrderCommandHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
        _products = products;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        UpdatePurchaseOrderCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var order = await _purchaseOrders.GetByIdAsync(
            tenantId, command.Id, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        var supplier = await _suppliers.GetByIdAsync(
            tenantId, command.SupplierId, cancellationToken);
        if (supplier is null) return Error.NotFound("Supplier not found.");
        var warehouse = await _warehouses.GetByIdAsync(
            tenantId, command.WarehouseId, cancellationToken);
        if (warehouse is null) return Error.NotFound("Warehouse not found.");

        foreach (var line in command.Lines)
        {
            var product = await _products.GetByIdAsync(
                tenantId, line.ProductId, cancellationToken);
            if (product is null) return Error.NotFound($"Product {line.ProductId} not found.");
            if (product.ProductType != ProductType.Product)
                return Error.Validation("Only physical products can be purchased.");
        }

        order.UpdateDraft(
            command.SupplierId, command.WarehouseId, command.BranchId,
            command.Lines.Select(l => (l.ProductId, l.Quantity, l.UnitPrice)),
            command.Reference, command.ExpectedDate, command.Notes);
        await _purchaseOrders.UpdateAsync(order, cancellationToken);

        var lines = order.Lines.Select(l => new PurchaseOrderLineDto(
            l.Id, l.ProductId, string.Empty, l.Quantity, l.UnitPrice, l.LineTotal));
        return Result.Success(PurchasingMappers.ToDto(
            order, supplier.Name, warehouse.Name, lines.ToList()));
    }
}

public sealed class CreatePurchaseOrderCommandHandler
    : IRequestHandler<CreatePurchaseOrderCommand, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IPurchaseOrderRepository _purchaseOrders;

    public CreatePurchaseOrderCommandHandler(
        ITenantContext tenantContext, ISupplierRepository suppliers,
        IWarehouseRepository warehouses, IProductRepository products,
        IPurchaseOrderRepository purchaseOrders)
    {
        _tenantContext = tenantContext;
        _suppliers = suppliers;
        _warehouses = warehouses;
        _products = products;
        _purchaseOrders = purchaseOrders;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        CreatePurchaseOrderCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var supplier = await _suppliers.GetByIdAsync(tenantId, command.SupplierId, cancellationToken);
        if (supplier is null) return Error.NotFound("Supplier not found.");
        if (!supplier.IsActive) return Error.Validation("Supplier is not active.");

        var warehouse = await _warehouses.GetByIdAsync(tenantId, command.WarehouseId, cancellationToken);
        if (warehouse is null) return Error.NotFound("Warehouse not found.");

        var productDtos = new List<PurchaseOrderLineDto>();
        foreach (var line in command.Lines)
        {
            var product = await _products.GetByIdAsync(tenantId, line.ProductId, cancellationToken);
            if (product is null) return Error.NotFound($"Product {line.ProductId} not found.");
            if (product.ProductType != ProductType.Product)
                return Error.Validation($"Only physical products can be purchased (product {line.ProductId}).");
            productDtos.Add(new PurchaseOrderLineDto(
                Guid.Empty, line.ProductId, product.Name, line.Quantity, line.UnitPrice, line.Quantity * line.UnitPrice));
        }

        var order = PurchaseOrder.Create(
            tenantId, command.SupplierId, command.WarehouseId, command.BranchId,
            command.Lines.Select(l => (l.ProductId, l.Quantity, l.UnitPrice)),
            command.Reference, command.ExpectedDate, command.Notes);

        await _purchaseOrders.AddAsync(order, cancellationToken);

        return Result.Success(PurchasingMappers.ToDto(
            order, supplier.Name, warehouse.Name,
            order.Lines.Zip(productDtos, (l, d) => d with { Id = l.Id }).ToList()));
    }
}

// ── Submit Purchase Order ──────────────────────────────────────────
public sealed record SubmitPurchaseOrderCommand(Guid Id)
    : IRequest<Result<PurchaseOrderDto>>, IRequiresTenantAdvisoryLock;

public sealed class SubmitPurchaseOrderCommandHandler
    : IRequestHandler<SubmitPurchaseOrderCommand, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;

    public SubmitPurchaseOrderCommandHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        SubmitPurchaseOrderCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var order = await _purchaseOrders.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        order.Submit(DateTime.UtcNow);
        await _purchaseOrders.UpdateAsync(order, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, order.SupplierId, cancellationToken);
        var warehouse = await _warehouses.GetByIdAsync(tenantId, order.WarehouseId, cancellationToken);
        var lines = order.Lines.Select(l => new PurchaseOrderLineDto(
            l.Id, l.ProductId, string.Empty, l.Quantity, l.UnitPrice, l.LineTotal)).ToList();

        return Result.Success(PurchasingMappers.ToDto(
            order, supplier?.Name ?? "Unknown", warehouse?.Name ?? "Unknown", lines));
    }
}

// ── Receive Purchase Order ─────────────────────────────────────────
public sealed record ReceivePurchaseOrderCommand(Guid Id)
    : IRequest<Result<PurchaseOrderDto>>, IRequiresTenantAdvisoryLock;

public sealed class ReceivePurchaseOrderCommandHandler
    : IRequestHandler<ReceivePurchaseOrderCommand, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IStockRepository _stock;

    public ReceivePurchaseOrderCommandHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses,
        IProductRepository products, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
        _products = products;
        _stock = stock;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        ReceivePurchaseOrderCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var order = await _purchaseOrders.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        var warehouse = await _warehouses.GetByIdAsync(tenantId, order.WarehouseId, cancellationToken);
        if (warehouse is null) return Error.NotFound("Warehouse not found.");

        var locationId = warehouse.Locations.FirstOrDefault()?.Id
            ?? throw new InvalidOperationException("Warehouse has no locations.");

        var receivedAt = DateTime.UtcNow;

        foreach (var line in order.Lines)
        {
            var product = await _products.GetByIdAsync(tenantId, line.ProductId, cancellationToken);
            var movement = StockMovement.Record(
                tenantId,
                warehouse.BranchId,
                order.WarehouseId,
                locationId,
                line.ProductId,
                null,
                StockMovementType.OpeningStock,
                line.Quantity,
                product?.UnitOfMeasureId ?? Guid.Empty,
                receivedAt,
                referenceType: "PurchaseOrder",
                referenceId: order.Id,
                reason: $"PO #{order.Reference ?? order.Id.ToString()[..8]} received",
                createdBy: _tenantContext.UserId);

            await _stock.AddMovementAsync(movement, cancellationToken);

            var balance = await _stock.GetOrCreateBalanceAsync(
                tenantId, order.WarehouseId, locationId, line.ProductId, null, cancellationToken);
            balance.Apply(line.Quantity);
        }

        order.Receive(receivedAt);
        await _purchaseOrders.UpdateAsync(order, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, order.SupplierId, cancellationToken);
        var lines = order.Lines.Select(l => new PurchaseOrderLineDto(
            l.Id, l.ProductId, string.Empty, l.Quantity, l.UnitPrice, l.LineTotal)).ToList();

        return Result.Success(PurchasingMappers.ToDto(
            order, supplier?.Name ?? "Unknown", warehouse.Name, lines));
    }
}

// ── Cancel Purchase Order ──────────────────────────────────────────
public sealed record CancelPurchaseOrderCommand(Guid Id)
    : IRequest<Result<PurchaseOrderDto>>, IRequiresTenantAdvisoryLock;

public sealed class CancelPurchaseOrderCommandHandler
    : IRequestHandler<CancelPurchaseOrderCommand, Result<PurchaseOrderDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly IWarehouseRepository _warehouses;

    public CancelPurchaseOrderCommandHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _warehouses = warehouses;
    }

    public async Task<Result<PurchaseOrderDto>> Handle(
        CancelPurchaseOrderCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var order = await _purchaseOrders.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        order.Cancel(DateTime.UtcNow);
        await _purchaseOrders.UpdateAsync(order, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, order.SupplierId, cancellationToken);
        var warehouse = await _warehouses.GetByIdAsync(tenantId, order.WarehouseId, cancellationToken);
        var lines = order.Lines.Select(l => new PurchaseOrderLineDto(
            l.Id, l.ProductId, string.Empty, l.Quantity, l.UnitPrice, l.LineTotal)).ToList();

        return Result.Success(PurchasingMappers.ToDto(
            order, supplier?.Name ?? "Unknown", warehouse?.Name ?? "Unknown", lines));
    }
}

// ── Create Supplier Bill ───────────────────────────────────────────
public sealed record CreateSupplierBillCommand(
    Guid PurchaseOrderId,
    decimal Subtotal,
    decimal TaxAmount,
    string? BillNumber,
    DateTime? BillDate,
    string? Notes)
    : IRequest<Result<SupplierBillDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateSupplierBillCommandHandler
    : IRequestHandler<CreateSupplierBillCommand, Result<SupplierBillDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPurchaseOrderRepository _purchaseOrders;
    private readonly ISupplierRepository _suppliers;
    private readonly ISupplierBillRepository _bills;

    public CreateSupplierBillCommandHandler(
        ITenantContext tenantContext, IPurchaseOrderRepository purchaseOrders,
        ISupplierRepository suppliers, ISupplierBillRepository bills)
    {
        _tenantContext = tenantContext;
        _purchaseOrders = purchaseOrders;
        _suppliers = suppliers;
        _bills = bills;
    }

    public async Task<Result<SupplierBillDto>> Handle(
        CreateSupplierBillCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var order = await _purchaseOrders.GetByIdAsync(tenantId, command.PurchaseOrderId, cancellationToken);
        if (order is null) return Error.NotFound("Purchase order not found.");

        var existingBill = await _bills.GetByPurchaseOrderAsync(tenantId, command.PurchaseOrderId, cancellationToken);
        if (existingBill is not null) return Error.Conflict("A bill already exists for this purchase order.");

        var supplier = await _suppliers.GetByIdAsync(tenantId, order.SupplierId, cancellationToken);

        var bill = SupplierBill.Create(
            tenantId, order.SupplierId, order.Id,
            command.Subtotal, command.TaxAmount,
            command.BillNumber, command.BillDate, command.Notes);

        await _bills.AddAsync(bill, cancellationToken);

        return Result.Success(PurchasingMappers.ToDto(bill, supplier?.Name ?? "Unknown"));
    }
}

// ── Approve Supplier Bill ──────────────────────────────────────────
public sealed record ApproveSupplierBillCommand(Guid Id)
    : IRequest<Result<SupplierBillDto>>, IRequiresTenantAdvisoryLock;

public sealed class ApproveSupplierBillCommandHandler
    : IRequestHandler<ApproveSupplierBillCommand, Result<SupplierBillDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierBillRepository _bills;
    private readonly ISupplierRepository _suppliers;

    public ApproveSupplierBillCommandHandler(
        ITenantContext tenantContext, ISupplierBillRepository bills, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _bills = bills;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierBillDto>> Handle(
        ApproveSupplierBillCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var bill = await _bills.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (bill is null) return Error.NotFound("Supplier bill not found.");

        bill.Approve(DateTime.UtcNow);
        await _bills.UpdateAsync(bill, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, bill.SupplierId, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(bill, supplier?.Name ?? "Unknown"));
    }
}

// ── Void Supplier Bill ─────────────────────────────────────────────
public sealed record VoidSupplierBillCommand(Guid Id)
    : IRequest<Result<SupplierBillDto>>, IRequiresTenantAdvisoryLock;

public sealed class VoidSupplierBillCommandHandler
    : IRequestHandler<VoidSupplierBillCommand, Result<SupplierBillDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierBillRepository _bills;
    private readonly ISupplierRepository _suppliers;

    public VoidSupplierBillCommandHandler(
        ITenantContext tenantContext, ISupplierBillRepository bills, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _bills = bills;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierBillDto>> Handle(
        VoidSupplierBillCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var bill = await _bills.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (bill is null) return Error.NotFound("Supplier bill not found.");

        bill.Void(DateTime.UtcNow);
        await _bills.UpdateAsync(bill, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, bill.SupplierId, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(bill, supplier?.Name ?? "Unknown"));
    }
}

// ── Create Supplier Payment ────────────────────────────────────────
public sealed record CreateSupplierPaymentCommand(
    Guid SupplierBillId,
    SupplierPaymentMethod Method,
    decimal Amount,
    string? Provider,
    string? Reference,
    string? PhoneNumber)
    : IRequest<Result<SupplierBillDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateSupplierPaymentCommandHandler
    : IRequestHandler<CreateSupplierPaymentCommand, Result<SupplierBillDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISupplierBillRepository _bills;
    private readonly ISupplierPaymentRepository _payments;
    private readonly ISupplierRepository _suppliers;

    public CreateSupplierPaymentCommandHandler(
        ITenantContext tenantContext, ISupplierBillRepository bills,
        ISupplierPaymentRepository payments, ISupplierRepository suppliers)
    {
        _tenantContext = tenantContext;
        _bills = bills;
        _payments = payments;
        _suppliers = suppliers;
    }

    public async Task<Result<SupplierBillDto>> Handle(
        CreateSupplierPaymentCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var bill = await _bills.GetByIdAsync(tenantId, command.SupplierBillId, cancellationToken);
        if (bill is null) return Error.NotFound("Supplier bill not found.");

        var payment = SupplierPayment.Create(
            bill.Id, command.Method, command.Amount,
            command.Provider, command.Reference, command.PhoneNumber);

        bill.RecordPayment(command.Amount, DateTime.UtcNow);
        await _bills.UpdateAsync(bill, cancellationToken);
        await _payments.AddAsync(payment, cancellationToken);

        var supplier = await _suppliers.GetByIdAsync(tenantId, bill.SupplierId, cancellationToken);
        return Result.Success(PurchasingMappers.ToDto(bill, supplier?.Name ?? "Unknown"));
    }
}
