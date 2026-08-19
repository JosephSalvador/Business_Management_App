using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record StockTransferredEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid TransferId,
    Guid TenantId,
    Guid SourceWarehouseId,
    Guid? SourceLocationId,
    Guid DestinationWarehouseId,
    Guid? DestinationLocationId,
    IReadOnlyList<StockTransferredLine> Lines,
    Guid? CreatedBy) : IDomainEvent;

public sealed record StockTransferredLine(
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity);
