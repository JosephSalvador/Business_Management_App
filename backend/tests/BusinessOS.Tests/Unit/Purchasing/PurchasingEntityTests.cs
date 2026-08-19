using BusinessOS.Domain.Purchasing;

namespace BusinessOS.Tests.Unit.Purchasing;

public sealed class SupplierTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public void Create_ValidSupplier_SetsActiveByDefault()
    {
        var supplier = Supplier.Create(TenantId, "Acme Supplies", "John", "john@acme.com");

        Assert.Equal("Acme Supplies", supplier.Name);
        Assert.Equal("John", supplier.ContactName);
        Assert.Equal("john@acme.com", supplier.Email);
        Assert.True(supplier.IsActive);
    }

    [Fact]
    public void Create_EmptyName_Throws()
        => Assert.Throws<ArgumentException>(() => Supplier.Create(TenantId, ""));

    [Fact]
    public void Create_WhitespaceName_Throws()
        => Assert.Throws<ArgumentException>(() => Supplier.Create(TenantId, "   "));

    [Fact]
    public void Deactivate_SetsInactive()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        supplier.Deactivate();
        Assert.False(supplier.IsActive);
    }

    [Fact]
    public void Activate_AfterDeactivate_SetsActive()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        supplier.Deactivate();
        supplier.Activate();
        Assert.True(supplier.IsActive);
    }

    [Fact]
    public void UpdateDetails_UpdatesFields()
    {
        var supplier = Supplier.Create(TenantId, "Acme");
        supplier.UpdateDetails("Jane", "jane@acme.com", "+255123", "Dar", "12345");

        Assert.Equal("Jane", supplier.ContactName);
        Assert.Equal("jane@acme.com", supplier.Email);
        Assert.Equal("+255123", supplier.Phone);
        Assert.Equal("Dar", supplier.Address);
        Assert.Equal("12345", supplier.Tin);
    }
}

public sealed class PurchaseOrderTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid SupplierId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid WarehouseId = new("33333333-3333-3333-3333-333333333333");
    private static readonly Guid ProductId = new("44444444-4444-4444-4444-444444444444");

    [Fact]
    public void Create_ValidPO_SetsDraftStatus()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null,
            [(ProductId, 10m, 100m)]);

        Assert.Equal(PurchaseOrderStatus.Draft, po.Status);
        Assert.Single(po.Lines);
        Assert.Equal(1000m, po.TotalAmount);
        Assert.Null(po.SubmittedAt);
        Assert.Null(po.ReceivedAt);
    }

    [Fact]
    public void Create_EmptySupplierId_Throws()
        => Assert.Throws<ArgumentException>(() => PurchaseOrder.Create(
            TenantId, Guid.Empty, WarehouseId, null, [(ProductId, 10m, 100m)]));

    [Fact]
    public void Create_EmptyWarehouseId_Throws()
        => Assert.Throws<ArgumentException>(() => PurchaseOrder.Create(
            TenantId, SupplierId, Guid.Empty, null, [(ProductId, 10m, 100m)]));

    [Fact]
    public void Create_EmptyLines_Throws()
        => Assert.Throws<ArgumentException>(() => PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, []));

    [Fact]
    public void Create_LineWithZeroQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 0m, 100m)]));

    [Fact]
    public void Create_LineWithNegativePrice_Throws()
        => Assert.Throws<ArgumentException>(() => PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, -5m)]));

    [Fact]
    public void Create_MultipleLines_ComputesTotal()
    {
        var product2 = Guid.NewGuid();
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null,
            [(ProductId, 10m, 100m), (product2, 5m, 200m)]);

        Assert.Equal(2000m, po.TotalAmount);
        Assert.Equal(2, po.Lines.Count);
    }

    [Fact]
    public void Submit_FromDraft_SetsSubmitted()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        var now = DateTime.UtcNow;

        po.Submit(now);

        Assert.Equal(PurchaseOrderStatus.Submitted, po.Status);
        Assert.Equal(now, po.SubmittedAt);
    }

    [Fact]
    public void Submit_FromSubmitted_Throws()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        po.Submit(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => po.Submit(DateTime.UtcNow));
    }

    [Fact]
    public void Receive_FromSubmitted_SetsReceived()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        po.Submit(DateTime.UtcNow);
        var now = DateTime.UtcNow;

        po.Receive(now);

        Assert.Equal(PurchaseOrderStatus.Received, po.Status);
        Assert.Equal(now, po.ReceivedAt);
    }

    [Fact]
    public void Receive_FromDraft_Throws()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);

        Assert.Throws<InvalidOperationException>(() => po.Receive(DateTime.UtcNow));
    }

    [Fact]
    public void Cancel_FromDraft_SetsCancelled()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        var now = DateTime.UtcNow;

        po.Cancel(now);

        Assert.Equal(PurchaseOrderStatus.Cancelled, po.Status);
        Assert.Equal(now, po.CancelledAt);
    }

    [Fact]
    public void Cancel_FromSubmitted_SetsCancelled()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        po.Submit(DateTime.UtcNow);

        po.Cancel(DateTime.UtcNow);

        Assert.Equal(PurchaseOrderStatus.Cancelled, po.Status);
    }

    [Fact]
    public void Cancel_FromReceived_Throws()
    {
        var po = PurchaseOrder.Create(
            TenantId, SupplierId, WarehouseId, null, [(ProductId, 10m, 100m)]);
        po.Submit(DateTime.UtcNow);
        po.Receive(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => po.Cancel(DateTime.UtcNow));
    }
}

public sealed class SupplierBillTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid SupplierId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid PurchaseOrderId = new("33333333-3333-3333-3333-333333333333");

    [Fact]
    public void Create_ValidBill_SetsDraftStatus()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);

        Assert.Equal(SupplierBillStatus.Draft, bill.Status);
        Assert.Equal(1000m, bill.Subtotal);
        Assert.Equal(180m, bill.TaxAmount);
        Assert.Equal(1180m, bill.TotalAmount);
        Assert.Equal(0m, bill.AmountPaid);
        Assert.Equal(1180m, bill.BalanceDue);
    }

    [Fact]
    public void Create_EmptySupplierId_Throws()
        => Assert.Throws<ArgumentException>(() => SupplierBill.Create(
            TenantId, Guid.Empty, PurchaseOrderId, 1000m, 180m));

    [Fact]
    public void Create_EmptyPurchaseOrderId_Throws()
        => Assert.Throws<ArgumentException>(() => SupplierBill.Create(
            TenantId, SupplierId, Guid.Empty, 1000m, 180m));

    [Fact]
    public void Create_NegativeSubtotal_Throws()
        => Assert.Throws<ArgumentException>(() => SupplierBill.Create(
            TenantId, SupplierId, PurchaseOrderId, -100m, 0m));

    [Fact]
    public void Create_NegativeTaxAmount_Throws()
        => Assert.Throws<ArgumentException>(() => SupplierBill.Create(
            TenantId, SupplierId, PurchaseOrderId, 100m, -10m));

    [Fact]
    public void Approve_FromDraft_SetsApproved()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        var now = DateTime.UtcNow;

        bill.Approve(now);

        Assert.Equal(SupplierBillStatus.Approved, bill.Status);
        Assert.Equal(now, bill.ApprovedAt);
    }

    [Fact]
    public void Approve_FromApproved_Throws()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => bill.Approve(DateTime.UtcNow));
    }

    [Fact]
    public void RecordPayment_PartialPayment_UpdatesBalance()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);

        bill.RecordPayment(500m, DateTime.UtcNow);

        Assert.Equal(500m, bill.AmountPaid);
        Assert.Equal(680m, bill.BalanceDue);
        Assert.Equal(SupplierBillStatus.Approved, bill.Status);
    }

    [Fact]
    public void RecordPayment_FullPayment_SetsPaid()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);

        bill.RecordPayment(1180m, DateTime.UtcNow);

        Assert.Equal(1180m, bill.AmountPaid);
        Assert.Equal(0m, bill.BalanceDue);
        Assert.Equal(SupplierBillStatus.Paid, bill.Status);
    }

    [Fact]
    public void RecordPayment_ExceedsBalance_Throws()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);

        Assert.Throws<ArgumentException>(() => bill.RecordPayment(2000m, DateTime.UtcNow));
    }

    [Fact]
    public void RecordPayment_ZeroAmount_Throws()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);

        Assert.Throws<ArgumentException>(() => bill.RecordPayment(0m, DateTime.UtcNow));
    }

    [Fact]
    public void Void_FromDraft_SetsVoid()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        var now = DateTime.UtcNow;

        bill.Void(now);

        Assert.Equal(SupplierBillStatus.Void, bill.Status);
        Assert.Equal(now, bill.VoidedAt);
    }

    [Fact]
    public void Void_FromPaid_Throws()
    {
        var bill = SupplierBill.Create(TenantId, SupplierId, PurchaseOrderId, 1000m, 180m);
        bill.Approve(DateTime.UtcNow);
        bill.RecordPayment(1180m, DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => bill.Void(DateTime.UtcNow));
    }
}

public sealed class SupplierPaymentTests
{
    private static readonly Guid SupplierBillId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public void Create_ValidPayment()
    {
        var payment = CreatePayment(500m);

        Assert.Equal(SupplierPaymentMethod.Cash, payment.Method);
        Assert.Equal(500m, payment.Amount);
    }

    [Fact]
    public void Create_ZeroAmount_Throws()
        => Assert.Throws<ArgumentException>(() => CreatePayment(0m));

    [Fact]
    public void Create_NegativeAmount_Throws()
        => Assert.Throws<ArgumentException>(() => CreatePayment(-10m));

    private static SupplierPayment CreatePayment(decimal amount)
        => SupplierPayment.Create(SupplierBillId, SupplierPaymentMethod.Cash, amount);
}
