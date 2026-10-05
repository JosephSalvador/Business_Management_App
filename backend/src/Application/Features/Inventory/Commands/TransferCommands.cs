using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

// ── Create Transfer ────────────────────────────────────────────────
public sealed record CreateTransferCommand(
    Guid SourceWarehouseId,
    Guid? SourceLocationId,
    Guid DestinationWarehouseId,
    Guid? DestinationLocationId,
    string? ReferenceType,
    Guid? ReferenceId,
    string? Reason,
    IReadOnlyList<TransferLineInput> Lines)
    : IRequest<Result<TransferDto>>, IRequiresTenantAdvisoryLock;

public sealed record TransferLineInput(
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity,
    Guid? BatchId);

public sealed class CreateTransferCommandHandler
    : IRequestHandler<CreateTransferCommand, Result<TransferDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly ITransferRepository _transfers;

    public CreateTransferCommandHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IProductRepository products,
        ITransferRepository transfers)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _products = products;
        _transfers = transfers;
    }

    public async Task<Result<TransferDto>> Handle(
        CreateTransferCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var sourceWarehouse = await _warehouses.GetByIdAsync(tenantId, command.SourceWarehouseId, cancellationToken);
        if (sourceWarehouse is null)
        {
            return Error.NotFound("Source warehouse not found.");
        }

        var destWarehouse = await _warehouses.GetByIdAsync(tenantId, command.DestinationWarehouseId, cancellationToken);
        if (destWarehouse is null)
        {
            return Error.NotFound("Destination warehouse not found.");
        }

        if (command.SourceLocationId.HasValue)
        {
            if (sourceWarehouse.Locations.All(l => l.Id != command.SourceLocationId.Value))
            {
                return Error.Validation("Source location does not belong to the source warehouse.");
            }
        }

        if (command.DestinationLocationId.HasValue)
        {
            if (destWarehouse.Locations.All(l => l.Id != command.DestinationLocationId.Value))
            {
                return Error.Validation("Destination location does not belong to the destination warehouse.");
            }
        }

        var productNames = new Dictionary<Guid, string>();

        foreach (var line in command.Lines)
        {
            var product = await _products.GetByIdAsync(tenantId, line.ProductId, cancellationToken);
            if (product is null)
            {
                return Error.NotFound($"Product {line.ProductId} not found.");
            }

            productNames[line.ProductId] = product.Name;

            if (product.ProductType != ProductType.Product)
            {
                return Error.Validation($"Only physical products can be transferred (product {line.ProductId}).");
            }

            if (product.HasVariants)
            {
                if (!line.VariantId.HasValue || product.Variants.All(v => v.Id != line.VariantId.Value))
                {
                    return Error.Validation($"A valid variant must be specified for product {line.ProductId}.");
                }
            }
            else if (line.VariantId.HasValue)
            {
                return Error.Validation($"Product {line.ProductId} has no variants.");
            }
        }

        var transferLines = command.Lines.Select(l =>
            (l.ProductId, l.VariantId, l.Quantity, l.BatchId)).ToList();

        var transfer = Transfer.Create(
            tenantId,
            command.SourceWarehouseId,
            command.SourceLocationId,
            command.DestinationWarehouseId,
            command.DestinationLocationId,
            transferLines,
            command.ReferenceType,
            command.ReferenceId,
            command.Reason);

        await _transfers.AddAsync(transfer, cancellationToken);

        return Result.Success(WarehouseMappers.ToTransferDto(
            transfer,
            sourceWarehouse.Name,
            destWarehouse.Name,
            productNames));
    }
}

// ── Complete Transfer ──────────────────────────────────────────────
public sealed record CompleteTransferCommand(Guid Id)
    : IRequest<Result<TransferDto>>, IRequiresTenantAdvisoryLock;

public sealed class CompleteTransferCommandHandler
    : IRequestHandler<CompleteTransferCommand, Result<TransferDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITransferRepository _transfers;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IStockRepository _stock;

    public CompleteTransferCommandHandler(
        ITenantContext tenantContext,
        ITransferRepository transfers,
        IWarehouseRepository warehouses,
        IProductRepository products,
        IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _transfers = transfers;
        _warehouses = warehouses;
        _products = products;
        _stock = stock;
    }

    public async Task<Result<TransferDto>> Handle(
        CompleteTransferCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var transfer = await _transfers.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (transfer is null)
        {
            return Error.NotFound("Transfer not found.");
        }

        if (transfer.Status != TransferStatus.Pending)
        {
            return Error.Conflict($"Transfer is already {transfer.Status}.");
        }

        var sourceWarehouse = await _warehouses.GetByIdAsync(tenantId, transfer.SourceWarehouseId, cancellationToken);
        var destWarehouse = await _warehouses.GetByIdAsync(tenantId, transfer.DestinationWarehouseId, cancellationToken);

        var sourceLocationId = transfer.SourceLocationId
            ?? sourceWarehouse?.Locations.FirstOrDefault()?.Id
            ?? throw new InvalidOperationException("Source warehouse has no locations.");

        var destLocationId = transfer.DestinationLocationId
            ?? destWarehouse?.Locations.FirstOrDefault()?.Id
            ?? throw new InvalidOperationException("Destination warehouse has no locations.");

        var completedAt = DateTime.UtcNow;
        var productNames = new Dictionary<Guid, string>();

        foreach (var line in transfer.Lines)
        {
            var sourceBalance = await _stock.GetBalanceWithLockAsync(
                tenantId, transfer.SourceWarehouseId, sourceLocationId,
                line.ProductId, line.VariantId, cancellationToken);

            if (sourceBalance is null || sourceBalance.Quantity < line.Quantity)
            {
                var available = sourceBalance?.Quantity ?? 0m;
                return Error.Validation(
                    $"Insufficient stock for product {line.ProductId}. " +
                    $"Required: {line.Quantity}, available: {available}.");
            }
        }

        foreach (var line in transfer.Lines)
        {
            var sourceBalance = await _stock.GetBalanceWithLockAsync(
                tenantId, transfer.SourceWarehouseId, sourceLocationId,
                line.ProductId, line.VariantId, cancellationToken);

            var destBalance = await _stock.GetOrCreateBalanceAsync(
                tenantId, transfer.DestinationWarehouseId, destLocationId,
                line.ProductId, line.VariantId, cancellationToken);

            var product = await _products.GetByIdAsync(tenantId, line.ProductId, cancellationToken);
            var uomId = product?.UnitOfMeasureId ?? Guid.Empty;
            productNames[line.ProductId] = product?.Name ?? string.Empty;

            var sourceMovement = StockMovement.Record(
                tenantId,
                sourceWarehouse!.BranchId,
                transfer.SourceWarehouseId,
                sourceLocationId,
                line.ProductId,
                line.VariantId,
                StockMovementType.TransferOut,
                -line.Quantity,
                uomId,
                completedAt,
                referenceType: "Transfer",
                referenceId: transfer.Id,
                reason: transfer.Reason,
                createdBy: _tenantContext.UserId);

            var destMovement = StockMovement.Record(
                tenantId,
                destWarehouse!.BranchId,
                transfer.DestinationWarehouseId,
                destLocationId,
                line.ProductId,
                line.VariantId,
                StockMovementType.TransferIn,
                line.Quantity,
                uomId,
                completedAt,
                referenceType: "Transfer",
                referenceId: transfer.Id,
                reason: transfer.Reason,
                createdBy: _tenantContext.UserId);

            await _stock.AddMovementAsync(sourceMovement, cancellationToken);
            await _stock.AddMovementAsync(destMovement, cancellationToken);

            sourceBalance!.Apply(-line.Quantity);
            destBalance.Apply(line.Quantity);
        }

        transfer.Complete(completedAt);
        await _transfers.UpdateAsync(transfer, cancellationToken);

        return Result.Success(WarehouseMappers.ToTransferDto(
            transfer,
            sourceWarehouse?.Name ?? "Unknown",
            destWarehouse?.Name ?? "Unknown",
            productNames));
    }
}

// ── Cancel Transfer ────────────────────────────────────────────────
public sealed record CancelTransferCommand(Guid Id)
    : IRequest<Result<TransferDto>>, IRequiresTenantAdvisoryLock;

public sealed class CancelTransferCommandHandler
    : IRequestHandler<CancelTransferCommand, Result<TransferDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITransferRepository _transfers;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;

    public CancelTransferCommandHandler(
        ITenantContext tenantContext,
        ITransferRepository transfers,
        IWarehouseRepository warehouses,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _transfers = transfers;
        _warehouses = warehouses;
        _products = products;
    }

    public async Task<Result<TransferDto>> Handle(
        CancelTransferCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var transfer = await _transfers.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (transfer is null)
        {
            return Error.NotFound("Transfer not found.");
        }

        if (transfer.Status != TransferStatus.Pending)
        {
            return Error.Conflict($"Cannot cancel a transfer in {transfer.Status} status.");
        }

        transfer.Cancel(DateTime.UtcNow);
        await _transfers.UpdateAsync(transfer, cancellationToken);

        var sourceWarehouse = await _warehouses.GetByIdAsync(tenantId, transfer.SourceWarehouseId, cancellationToken);
        var destWarehouse = await _warehouses.GetByIdAsync(tenantId, transfer.DestinationWarehouseId, cancellationToken);

        var productNames = new Dictionary<Guid, string>();
        foreach (var line in transfer.Lines)
        {
            if (productNames.ContainsKey(line.ProductId))
            {
                continue;
            }

            var product = await _products.GetByIdAsync(tenantId, line.ProductId, cancellationToken);
            productNames[line.ProductId] = product?.Name ?? string.Empty;
        }

        return Result.Success(WarehouseMappers.ToTransferDto(
            transfer,
            sourceWarehouse?.Name ?? "Unknown",
            destWarehouse?.Name ?? "Unknown",
            productNames));
    }
}
