using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

// ── Create Stock Batch ─────────────────────────────────────────────
public sealed record CreateStockBatchCommand(
    Guid ProductId,
    Guid? VariantId,
    string BatchNumber,
    DateTime? ManufacturerDate,
    DateTime? ExpiryDate,
    Guid? SupplierId,
    string? Notes)
    : IRequest<Result<StockBatchDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateStockBatchCommandHandler
    : IRequestHandler<CreateStockBatchCommand, Result<StockBatchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;
    private readonly IStockBatchRepository _batches;

    public CreateStockBatchCommandHandler(
        ITenantContext tenantContext,
        IProductRepository products,
        IStockBatchRepository batches)
    {
        _tenantContext = tenantContext;
        _products = products;
        _batches = batches;
    }

    public async Task<Result<StockBatchDto>> Handle(
        CreateStockBatchCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var product = await _products.GetByIdAsync(tenantId, command.ProductId, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        if (product.ProductType != ProductType.Product)
        {
            return Error.Validation("Only physical products can have batches.");
        }

        if (product.HasVariants)
        {
            if (!command.VariantId.HasValue || product.Variants.All(v => v.Id != command.VariantId.Value))
            {
                return Error.Validation("A variant belonging to the product must be specified.");
            }
        }
        else if (command.VariantId.HasValue)
        {
            return Error.Validation("This product has no variants.");
        }

        var existing = await _batches.GetByBatchNumberAsync(
            tenantId, command.ProductId, command.BatchNumber, cancellationToken);
        if (existing is not null)
        {
            return Error.Conflict($"A batch with number '{command.BatchNumber}' already exists for this product.");
        }

        var batch = StockBatch.Create(
            tenantId,
            command.ProductId,
            command.VariantId,
            command.BatchNumber,
            command.ManufacturerDate,
            command.ExpiryDate,
            command.SupplierId,
            command.Notes);

        await _batches.AddAsync(batch, cancellationToken);

        return Result.Success(WarehouseMappers.ToStockBatchDto(batch, product.Name));
    }
}

// ── Set Stock Batch Status ─────────────────────────────────────────
public sealed record SetStockBatchStatusCommand(Guid Id, bool IsActive)
    : IRequest<Result<StockBatchDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetStockBatchStatusCommandHandler
    : IRequestHandler<SetStockBatchStatusCommand, Result<StockBatchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockBatchRepository _batches;
    private readonly IProductRepository _products;

    public SetStockBatchStatusCommandHandler(
        ITenantContext tenantContext,
        IStockBatchRepository batches,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _batches = batches;
        _products = products;
    }

    public async Task<Result<StockBatchDto>> Handle(
        SetStockBatchStatusCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var batch = await _batches.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (batch is null)
        {
            return Error.NotFound("Stock batch not found.");
        }

        if (command.IsActive)
        {
            batch.Activate();
        }
        else
        {
            batch.Deactivate();
        }

        await _batches.UpdateAsync(batch, cancellationToken);

        var product = await _products.GetByIdAsync(tenantId, batch.ProductId, cancellationToken);
        return Result.Success(WarehouseMappers.ToStockBatchDto(batch, product?.Name ?? "Unknown"));
    }
}
