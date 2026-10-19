using BusinessOS.Application.Features.Purchasing.Commands;
using BusinessOS.Application.Features.Purchasing.Queries;
using BusinessOS.Application.Features.Purchasing.Validators;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Purchasing;

public sealed class CreateSupplierCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidSupplier_ReturnsSuccess()
    {
        var handler = new CreateSupplierCommandHandler(PurchasingTestHelper.StubTenant(), new StubSupplierRepository());
        var result = await handler.Handle(
            new CreateSupplierCommand("Acme", "John", "john@acme.com", null, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal("Acme", result.Value.Name);
    }

    [Fact]
    public async Task DuplicateName_ReturnsConflict()
    {
        var repo = new StubSupplierRepository();
        repo.Seed(Supplier.Create(TenantId, "Acme"));

        var handler = new CreateSupplierCommandHandler(PurchasingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new CreateSupplierCommand("Acme", null, null, null, null, null, null),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Conflict", result.Error.Code);
    }
}

public sealed class UpdateSupplierCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidUpdate_ReturnsSuccess()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        var repo = new StubSupplierRepository();
        repo.Seed(supplier);

        var handler = new UpdateSupplierCommandHandler(PurchasingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new UpdateSupplierCommand(supplier.Id, "Acme Updated", "Jane", "jane@acme.com", null, null, null, null, true),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal("Acme", result.Value.Name);
        Assert.Equal("Jane", result.Value.ContactName);
    }

    [Fact]
    public async Task NotFound_ReturnsError()
    {
        var handler = new UpdateSupplierCommandHandler(PurchasingTestHelper.StubTenant(), new StubSupplierRepository());
        var result = await handler.Handle(
            new UpdateSupplierCommand(Guid.NewGuid(), "X", null, null, null, null, null, null, true),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }
}

public sealed class CreatePurchaseOrderCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidPO_ReturnsSuccess()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();
        var result = await handler.Handle(
            new CreatePurchaseOrderCommand(
                world.Supplier.Id, world.Warehouse.Id, null, "REF-001", null, null,
                [new PurchaseOrderLineInput(world.Product.Id, 10m, 100m)]),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(PurchaseOrderStatus.Draft, result.Value.Status);
        Assert.Equal(1000m, result.Value.TotalAmount);
        Assert.Equal("Acme Supplier", result.Value.SupplierName);
    }

    [Fact]
    public async Task InactiveSupplier_ReturnsValidationError()
    {
        var supplier = Supplier.Create(TenantId, "Acme Supplier");
        supplier.Deactivate();
        var world = BuildWorld(supplier: supplier);
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            new CreatePurchaseOrderCommand(
                supplier.Id, world.Warehouse.Id, null, null, null, null,
                [new PurchaseOrderLineInput(world.Product.Id, 10m, 100m)]),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Contains("not active", result.Error.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task NonExistentSupplier_ReturnsNotFound()
    {
        var handler = new CreatePurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), new StubSupplierRepository(), new StubWarehouseRepository(),
            new StubProductRepository(), new StubPurchaseOrderRepository());

        var result = await handler.Handle(
            new CreatePurchaseOrderCommand(
                Guid.NewGuid(), Guid.NewGuid(), null, null, null, null,
                [new PurchaseOrderLineInput(Guid.NewGuid(), 10m, 100m)]),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }

    private static TestWorld BuildWorld(
        Supplier? supplier = null,
        Warehouse? warehouse = null,
        Product? product = null)
    {
        supplier ??= Supplier.Create(TenantId, "Acme Supplier");
        warehouse ??= Warehouse.Create(TenantId, Guid.NewGuid(), "Main Warehouse", "WH-001");
        product ??= Product.Create(TenantId, "Widget", null, "SKU-W001", null, null, null, Guid.NewGuid(), ProductType.Product);

        return new TestWorld(supplier, warehouse, product);
    }

    private static CreatePurchaseOrderCommandHandler CreateHandler()
        => BuildWorld().CreateHandler();

    private sealed class TestWorld
    {
        public Supplier Supplier { get; }
        public Warehouse Warehouse { get; }
        public Product Product { get; }

        public TestWorld(Supplier supplier, Warehouse warehouse, Product product)
        {
            Supplier = supplier;
            Warehouse = warehouse;
            Product = product;
        }

        public CreatePurchaseOrderCommandHandler CreateHandler()
        {
            var supplierRepo = new StubSupplierRepository();
            supplierRepo.Seed(Supplier);
            var warehouseRepo = new StubWarehouseRepository();
            warehouseRepo.Seed(Warehouse);
            var productRepo = new StubProductRepository();
            productRepo.Seed(Product);

            return new CreatePurchaseOrderCommandHandler(
                PurchasingTestHelper.StubTenant(), supplierRepo, warehouseRepo, productRepo, new StubPurchaseOrderRepository());
        }
    }
}

public sealed class SubmitPurchaseOrderCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task FromDraft_ReturnsSubmitted()
    {
        var po = PurchaseOrder.Create(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), null,
            [(Guid.NewGuid(), 10m, 100m)]);
        var world = BuildWorld(po);

        var result = await world.Handler.Handle(
            new SubmitPurchaseOrderCommand(po.Id), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(PurchaseOrderStatus.Submitted, result.Value.Status);
    }

    [Fact]
    public async Task NotFound_ReturnsError()
    {
        var handler = new SubmitPurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), new StubPurchaseOrderRepository(), new StubSupplierRepository(), new StubWarehouseRepository());
        var result = await handler.Handle(
            new SubmitPurchaseOrderCommand(Guid.NewGuid()), CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }

    private static (SubmitPurchaseOrderCommandHandler Handler, StubPurchaseOrderRepository POs) BuildWorld(PurchaseOrder po)
    {
        var poRepo = new StubPurchaseOrderRepository();
        poRepo.Seed(po);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(Supplier.Create(TenantId, "Acme"));
        var warehouseRepo = new StubWarehouseRepository();
        warehouseRepo.Seed(Warehouse.Create(TenantId, Guid.NewGuid(), "Main", "WH-001"));

        return (new SubmitPurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), poRepo, supplierRepo, warehouseRepo), poRepo);
    }
}

public sealed class ReceivePurchaseOrderCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task FromSubmitted_RecordsStockMovements()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        var warehouse = Warehouse.Create(TenantId, Guid.NewGuid(), "Main Warehouse", "WH-001");
        var product = Product.Create(TenantId, "Widget", null, "SKU-W001", null, null, null, Guid.NewGuid(), ProductType.Product);
        var po = PurchaseOrder.Create(TenantId, supplier.Id, warehouse.Id, null, [(product.Id, 10m, 100m)]);
        po.Submit(DateTime.UtcNow);

        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(supplier);
        var warehouseRepo = new StubWarehouseRepository();
        warehouseRepo.Seed(warehouse);
        var productRepo = new StubProductRepository();
        productRepo.Seed(product);
        var poRepo = new StubPurchaseOrderRepository();
        poRepo.Seed(po);
        var stockRepo = new StubStockRepository();

        var handler = new ReceivePurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), poRepo, supplierRepo, warehouseRepo, productRepo, stockRepo);

        var result = await handler.Handle(new ReceivePurchaseOrderCommand(po.Id), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(PurchaseOrderStatus.Received, result.Value.Status);
        Assert.Single(stockRepo.Movements);
        Assert.Equal(StockMovementType.OpeningStock, stockRepo.Movements[0].MovementType);
        Assert.Equal(10m, stockRepo.Movements[0].Quantity);
    }

    [Fact]
    public async Task NotFound_ReturnsError()
    {
        var handler = new ReceivePurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), new StubPurchaseOrderRepository(), new StubSupplierRepository(),
            new StubWarehouseRepository(), new StubProductRepository(), new StubStockRepository());

        var result = await handler.Handle(new ReceivePurchaseOrderCommand(Guid.NewGuid()), CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }
}

public sealed class CancelPurchaseOrderCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task FromDraft_ReturnsCancelled()
    {
        var po = PurchaseOrder.Create(TenantId, Guid.NewGuid(), Guid.NewGuid(), null, [(Guid.NewGuid(), 5m, 50m)]);
        var poRepo = new StubPurchaseOrderRepository();
        poRepo.Seed(po);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(Supplier.Create(TenantId, "Acme"));
        var warehouseRepo = new StubWarehouseRepository();
        warehouseRepo.Seed(Warehouse.Create(TenantId, Guid.NewGuid(), "Main", "WH-001"));

        var handler = new CancelPurchaseOrderCommandHandler(
            PurchasingTestHelper.StubTenant(), poRepo, supplierRepo, warehouseRepo);
        var result = await handler.Handle(new CancelPurchaseOrderCommand(po.Id), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(PurchaseOrderStatus.Cancelled, result.Value.Status);
    }
}

public sealed class CreateSupplierBillCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidBill_ReturnsSuccess()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        var product = Guid.NewGuid();
        var po = PurchaseOrder.Create(TenantId, supplier.Id, Guid.NewGuid(), null, [(product, 10m, 100m)]);
        var poRepo = new StubPurchaseOrderRepository();
        poRepo.Seed(po);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(supplier);

        var handler = new CreateSupplierBillCommandHandler(
            PurchasingTestHelper.StubTenant(), poRepo, supplierRepo, new StubSupplierBillRepository());
        var result = await handler.Handle(
            new CreateSupplierBillCommand(po.Id, 1000m, 180m, "BILL-001", null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(1000m, result.Value.Subtotal);
        Assert.Equal(180m, result.Value.TaxAmount);
        Assert.Equal(1180m, result.Value.TotalAmount);
        Assert.Equal(SupplierBillStatus.Draft, result.Value.Status);
    }

    [Fact]
    public async Task DuplicatePO_ReturnsConflict()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        var product = Guid.NewGuid();
        var po = PurchaseOrder.Create(TenantId, supplier.Id, Guid.NewGuid(), null, [(product, 10m, 100m)]);
        var poRepo = new StubPurchaseOrderRepository();
        poRepo.Seed(po);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(supplier);

        var billRepo = new StubSupplierBillRepository();
        billRepo.SeedBillsForPO(po.Id, SupplierBill.Create(TenantId, supplier.Id, po.Id, 500m, 90m));

        var handler = new CreateSupplierBillCommandHandler(
            PurchasingTestHelper.StubTenant(), poRepo, supplierRepo, billRepo);
        var result = await handler.Handle(
            new CreateSupplierBillCommand(po.Id, 1000m, 180m, null, null, null),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Conflict", result.Error.Code);
    }
}

public sealed class ApproveSupplierBillCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task FromDraft_ReturnsApproved()
    {
        var bill = SupplierBill.Create(TenantId, Guid.NewGuid(), Guid.NewGuid(), 1000m, 180m);
        var billRepo = new StubSupplierBillRepository();
        billRepo.Seed(bill);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(Supplier.Create(TenantId, "Acme"));

        var handler = new ApproveSupplierBillCommandHandler(PurchasingTestHelper.StubTenant(), billRepo, supplierRepo);
        var result = await handler.Handle(new ApproveSupplierBillCommand(bill.Id), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(SupplierBillStatus.Approved, result.Value.Status);
    }
}

public sealed class VoidSupplierBillCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task FromDraft_ReturnsVoid()
    {
        var bill = SupplierBill.Create(TenantId, Guid.NewGuid(), Guid.NewGuid(), 1000m, 180m);
        var billRepo = new StubSupplierBillRepository();
        billRepo.Seed(bill);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(Supplier.Create(TenantId, "Acme"));

        var handler = new VoidSupplierBillCommandHandler(PurchasingTestHelper.StubTenant(), billRepo, supplierRepo);
        var result = await handler.Handle(new VoidSupplierBillCommand(bill.Id), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(SupplierBillStatus.Void, result.Value.Status);
    }
}

public sealed class CreateSupplierPaymentCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidPayment_UpdatesBillBalance()
    {
        var bill = SupplierBill.Create(TenantId, Guid.NewGuid(), Guid.NewGuid(), 1000m, 180m);
        bill.Approve(DateTime.UtcNow);
        var billRepo = new StubSupplierBillRepository();
        billRepo.Seed(bill);
        var supplierRepo = new StubSupplierRepository();
        supplierRepo.Seed(Supplier.Create(TenantId, "Acme"));

        var handler = new CreateSupplierPaymentCommandHandler(
            PurchasingTestHelper.StubTenant(), billRepo, new StubSupplierPaymentRepository(), supplierRepo);
        var result = await handler.Handle(
            new CreateSupplierPaymentCommand(bill.Id, SupplierPaymentMethod.Cash, 500m, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(500m, result.Value.AmountPaid);
        Assert.Equal(680m, result.Value.BalanceDue);
    }
}

public sealed class ListSuppliersQueryTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ReturnsPagedResults()
    {
        var repo = new StubSupplierRepository();
        repo.Seed(Supplier.Create(TenantId, "Acme"));
        repo.Seed(Supplier.Create(TenantId, "Beta Corp"));

        var handler = new ListSuppliersQueryHandler(PurchasingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(new ListSuppliersQuery(1, 10), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(2, result.Value.Items.Count);
        Assert.Equal(2, result.Value.Total);
    }
}

public sealed class ValidatorTests
{
    [Fact]
    public void CreateSupplier_EmptyName_Fails()
    {
        var validator = new CreateSupplierCommandValidator();
        var result = validator.Validate(new CreateSupplierCommand("", null, null, null, null, null, null));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreateSupplier_Valid_Passes()
    {
        var validator = new CreateSupplierCommandValidator();
        var result = validator.Validate(new CreateSupplierCommand("Acme", null, null, null, null, null, null));
        Assert.True(result.IsValid);
    }

    [Fact]
    public void CreatePO_EmptyLines_Fails()
    {
        var validator = new CreatePurchaseOrderCommandValidator();
        var result = validator.Validate(new CreatePurchaseOrderCommand(
            Guid.NewGuid(), Guid.NewGuid(), null, null, null, null, []));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePO_ZeroQuantity_Fails()
    {
        var validator = new CreatePurchaseOrderCommandValidator();
        var result = validator.Validate(new CreatePurchaseOrderCommand(
            Guid.NewGuid(), Guid.NewGuid(), null, null, null, null,
            [new PurchaseOrderLineInput(Guid.NewGuid(), 0m, 100m)]));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePO_Valid_Passes()
    {
        var validator = new CreatePurchaseOrderCommandValidator();
        var result = validator.Validate(new CreatePurchaseOrderCommand(
            Guid.NewGuid(), Guid.NewGuid(), null, null, null, null,
            [new PurchaseOrderLineInput(Guid.NewGuid(), 5m, 100m)]));
        Assert.True(result.IsValid);
    }

    [Fact]
    public void CreateBill_NegativeSubtotal_Fails()
    {
        var validator = new CreateSupplierBillCommandValidator();
        var result = validator.Validate(new CreateSupplierBillCommand(
            Guid.NewGuid(), -1m, 0m, null, null, null));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePayment_ZeroAmount_Fails()
    {
        var validator = new CreateSupplierPaymentCommandValidator();
        var result = validator.Validate(new CreateSupplierPaymentCommand(
            Guid.NewGuid(), SupplierPaymentMethod.Cash, 0m, null, null, null));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void ListSuppliersQuery_PageZero_Fails()
    {
        var validator = new ListSuppliersQueryValidator();
        var result = validator.Validate(new ListSuppliersQuery(0, 10));
        Assert.False(result.IsValid);
    }

    [Fact]
    public void ListPOQuery_PageZero_Fails()
    {
        var validator = new ListPurchaseOrdersQueryValidator();
        var result = validator.Validate(new ListPurchaseOrdersQuery(0, 10));
        Assert.False(result.IsValid);
    }
}

// ── Shared helper ──────────────────────────────────────────────────
internal static class PurchasingTestHelper
{
    private static readonly Guid DefaultTenantId = new("11111111-1111-1111-1111-111111111111");
    public static ITenantContext StubTenant() => new StubTenantContext(DefaultTenantId);
}

internal sealed class StubTenantContext(Guid tenantId) : ITenantContext
{
    public Guid TenantId => tenantId;
    public Guid? UserId => Guid.NewGuid();
    public string? IpAddress => "127.0.0.1";
    public string? UserAgent => null;
    public string? CurrentRefreshToken => null;
}

internal sealed class StubSupplierRepository : ISupplierRepository
{
    private readonly List<Supplier> _seeded = [];
    public void Seed(Supplier supplier) => _seeded.Add(supplier);
    public Task AddAsync(Supplier s, CancellationToken ct = default) { _seeded.Add(s); return Task.CompletedTask; }
    public Task UpdateAsync(Supplier s, CancellationToken ct = default) => Task.CompletedTask;
    public Task<Supplier?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(s => s.Id == id));
    public Task<IReadOnlyList<Supplier>> ListAsync(Guid tenantId, int page, int pageSize, string? search = null, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Supplier>>(
            _seeded.Where(s => string.IsNullOrEmpty(search) || s.Name.Contains(search)).ToList());
    public Task<int> CountAsync(Guid tenantId, string? search = null, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count(s => string.IsNullOrEmpty(search) || s.Name.Contains(search)));
}

internal sealed class StubPurchaseOrderRepository : IPurchaseOrderRepository
{
    private readonly List<PurchaseOrder> _seeded = [];
    public PurchaseOrder? LastAdded { get; private set; }
    public void Seed(PurchaseOrder po) => _seeded.Add(po);
    public Task AddAsync(PurchaseOrder po, CancellationToken ct = default) { _seeded.Add(po); LastAdded = po; return Task.CompletedTask; }
    public Task UpdateAsync(PurchaseOrder po, CancellationToken ct = default) => Task.CompletedTask;
    public Task<PurchaseOrder?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(o => o.Id == id));
    public Task<IReadOnlyList<PurchaseOrder>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<PurchaseOrder>>(_seeded.Skip((page - 1) * pageSize).Take(pageSize).ToList());
    public Task<IReadOnlyList<PurchaseOrder>> ListByDateRangeAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<PurchaseOrder>>(_seeded.Where(o => o.CreatedAt >= from && o.CreatedAt <= to).ToList());
    public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count);
}

internal sealed class StubSupplierBillRepository : ISupplierBillRepository
{
    private readonly List<SupplierBill> _seeded = [];
    public void Seed(SupplierBill bill) => _seeded.Add(bill);
    public void SeedBillsForPO(Guid poId, SupplierBill bill) => _seeded.Add(bill);
    public Task AddAsync(SupplierBill b, CancellationToken ct = default) { _seeded.Add(b); return Task.CompletedTask; }
    public Task UpdateAsync(SupplierBill b, CancellationToken ct = default) => Task.CompletedTask;
    public Task<SupplierBill?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(b => b.Id == id));
    public Task<SupplierBill?> GetByPurchaseOrderAsync(Guid tenantId, Guid poId, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(b => b.PurchaseOrderId == poId));
    public Task<IReadOnlyList<SupplierBill>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<SupplierBill>>(_seeded.Skip((page - 1) * pageSize).Take(pageSize).ToList());
    public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count);
}

internal sealed class StubSupplierPaymentRepository : ISupplierPaymentRepository
{
    private readonly List<SupplierPayment> _seeded = [];
    public Task AddAsync(SupplierPayment p, CancellationToken ct = default) { _seeded.Add(p); return Task.CompletedTask; }
    public Task<IReadOnlyList<SupplierBill>> ListByBillAsync(Guid tenantId, Guid supplierBillId, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<SupplierBill>>([]);
}

internal sealed class StubWarehouseRepository : IWarehouseRepository
{
    private readonly List<Warehouse> _seeded = [];
    public void Seed(Warehouse w) => _seeded.Add(w);
    public Task AddAsync(Warehouse w, CancellationToken ct = default) { _seeded.Add(w); return Task.CompletedTask; }
    public Task<Warehouse?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(w => w.Id == id));
    public Task<Warehouse?> GetByCodeAsync(Guid tenantId, string code, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(w => w.Code == code));
    public Task<IReadOnlyList<Warehouse>> ListAsync(
        Guid tenantId, int page, int pageSize, string? search, Guid? branchId, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Warehouse>>(_seeded);
    public Task<int> CountAsync(Guid tenantId, string? search, Guid? branchId, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count);
}

internal sealed class StubProductRepository : IProductRepository
{
    private readonly List<Product> _seeded = [];
    public void Seed(Product p) => _seeded.Add(p);
    public Task AddAsync(Product p, CancellationToken ct = default) { _seeded.Add(p); return Task.CompletedTask; }
    public Task UpdateAsync(Product p, CancellationToken ct = default) => Task.CompletedTask;
    public Task<Product?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(p => p.Id == id));
    public Task<IReadOnlyList<Product>> GetByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default)
    {
        var idSet = ids.ToHashSet();
        return Task.FromResult<IReadOnlyList<Product>>(_seeded.Where(p => idSet.Contains(p.Id)).ToList());
    }
    public Task<Product?> GetBySkuAsync(Guid tenantId, string sku, CancellationToken ct = default)
        => Task.FromResult<Product?>(null);
    public Task<Product?> GetByBarcodeAsync(Guid tenantId, string barcode, CancellationToken ct = default)
        => Task.FromResult<Product?>(null);
    public Task<IReadOnlyList<Product>> ListAsync(
        Guid tenantId, int page, int pageSize, ProductListFilter filter, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Product>>(_seeded);
    public Task<int> CountAsync(Guid tenantId, ProductListFilter filter, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count);
    public Task<bool> VariantSkuExistsAsync(Guid tenantId, string sku, Guid? excludeProductId = null, CancellationToken ct = default)
        => Task.FromResult(false);
    public Task<bool> VariantBarcodeExistsAsync(Guid tenantId, string barcode, Guid? excludeProductId = null, CancellationToken ct = default)
        => Task.FromResult(false);
}

internal sealed class StubStockRepository : IStockRepository
{
    public List<StockMovement> Movements { get; } = [];
    public StockBalance? Balance { get; set; }

    public Task AddMovementAsync(StockMovement m, CancellationToken ct = default) { Movements.Add(m); return Task.CompletedTask; }
    public Task<StockBalance?> GetBalanceAsync(Guid tenantId, Guid warehouseId, Guid locationId, Guid productId, Guid? variantId, CancellationToken ct = default)
        => Task.FromResult(Balance);
    public Task<StockBalance?> GetBalanceWithLockAsync(Guid tenantId, Guid warehouseId, Guid locationId, Guid productId, Guid? variantId, CancellationToken ct = default)
        => Task.FromResult(Balance);
    public Task<StockBalance> GetOrCreateBalanceAsync(Guid tenantId, Guid warehouseId, Guid locationId, Guid productId, Guid? variantId, CancellationToken ct = default)
    {
        if (Balance is null)
        {
            Balance = StockBalance.Create(tenantId, warehouseId, locationId, productId, variantId);
        }
        return Task.FromResult(Balance);
    }
    public Task<IReadOnlyList<StockBalanceView>> ListBalancesAsync(Guid tenantId, int page, int pageSize, Guid? warehouseId, Guid? productId, string? search, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<StockBalanceView>>(Array.Empty<StockBalanceView>());
    public Task<int> CountBalancesAsync(Guid tenantId, Guid? warehouseId, Guid? productId, string? search, CancellationToken ct = default)
        => Task.FromResult(Balance is null ? 0 : 1);
    public Task<IReadOnlyList<StockMovementView>> ListMovementsAsync(Guid tenantId, int page, int pageSize, Guid? warehouseId, Guid? productId, StockMovementType? type, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<StockMovementView>>(Array.Empty<StockMovementView>());
    public Task<int> CountMovementsAsync(Guid tenantId, Guid? warehouseId, Guid? productId, StockMovementType? type, CancellationToken ct = default)
        => Task.FromResult(Movements.Count);
    public Task<IReadOnlyList<StockMovement>> ListMovementsByReferenceAsync(Guid tenantId, string referenceType, Guid referenceId, StockMovementType? type, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<StockMovement>>(Movements.Where(m => m.ReferenceId == referenceId).ToList());
    public Task<StockMovement?> FindAdjustmentByKeyAsync(Guid tenantId, string correlationId, CancellationToken ct = default)
        => Task.FromResult(Movements.FirstOrDefault(m =>
            m.CorrelationId == correlationId));

    public Task<IReadOnlyList<StockSummaryRow>> GetStockSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<StockSummaryRow>>(new List<StockSummaryRow>());

    public Task<IReadOnlyList<StockMovementSummaryRow>> GetStockMovementSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<StockMovementSummaryRow>>(new List<StockMovementSummaryRow>());

    public Task<IReadOnlyList<LowStockReportItem>> GetLowStockReportAsync(
        Guid tenantId, decimal threshold, Guid? warehouseId, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<LowStockReportItem>>(new List<LowStockReportItem>());

    public Task<IReadOnlyList<StockVelocityRow>> GetStockVelocityAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<StockVelocityRow>>(new List<StockVelocityRow>());
}
