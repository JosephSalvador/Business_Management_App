using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record PurchaseOrderCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid PurchaseOrderId,
    Guid TenantId,
    Guid SupplierId,
    Guid WarehouseId,
    decimal TotalAmount) : IDomainEvent;

public sealed record PurchaseOrderReceivedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid PurchaseOrderId,
    Guid TenantId,
    Guid SupplierId,
    Guid WarehouseId) : IDomainEvent;

public sealed record SupplierBillCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SupplierBillId,
    Guid TenantId,
    Guid SupplierId,
    Guid PurchaseOrderId,
    decimal TotalAmount) : IDomainEvent;

public sealed record SupplierBillPaidEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SupplierBillId,
    Guid TenantId,
    Guid SupplierId,
    decimal AmountPaid,
    decimal BalanceDue) : IDomainEvent;
