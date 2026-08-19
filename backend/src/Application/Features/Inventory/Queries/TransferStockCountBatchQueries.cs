using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Inventory.Commands;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Queries;

public sealed record ListTransfersQuery(int Page, int PageSize)
    : IRequest<Result<PagedResult<TransferSummaryDto>>>;

public sealed class ListTransfersQueryHandler
    : IRequestHandler<ListTransfersQuery, Result<PagedResult<TransferSummaryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITransferRepository _transfers;
    private readonly IWarehouseRepository _warehouses;

    public ListTransfersQueryHandler(
        ITenantContext tenantContext,
        ITransferRepository transfers,
        IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _transfers = transfers;
        _warehouses = warehouses;
    }

    public async Task<Result<PagedResult<TransferSummaryDto>>> Handle(
        ListTransfersQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _transfers.ListAsync(tenantId, query.Page, query.PageSize, cancellationToken);
        var total = await _transfers.CountAsync(tenantId, cancellationToken);

        var warehouses = new Dictionary<Guid, string>();
        foreach (var transfer in items)
        {
            if (!warehouses.ContainsKey(transfer.SourceWarehouseId))
            {
                var wh = await _warehouses.GetByIdAsync(tenantId, transfer.SourceWarehouseId, cancellationToken);
                warehouses[transfer.SourceWarehouseId] = wh?.Name ?? "Unknown";
            }
            if (!warehouses.ContainsKey(transfer.DestinationWarehouseId))
            {
                var wh = await _warehouses.GetByIdAsync(tenantId, transfer.DestinationWarehouseId, cancellationToken);
                warehouses[transfer.DestinationWarehouseId] = wh?.Name ?? "Unknown";
            }
        }

        var summaries = items.Select(t => new TransferSummaryDto(
            t.Id,
            warehouses.TryGetValue(t.SourceWarehouseId, out var srcName) ? srcName : "Unknown",
            warehouses.TryGetValue(t.DestinationWarehouseId, out var dstName) ? dstName : "Unknown",
            t.Status,
            t.Lines.Count,
            t.Reason,
            t.CreatedAt)).ToList();

        return Result.Success(new PagedResult<TransferSummaryDto>(summaries, query.Page, query.PageSize, total));
    }
}

public sealed record GetTransferQuery(Guid Id)
    : IRequest<Result<TransferDto>>;

public sealed class GetTransferQueryHandler
    : IRequestHandler<GetTransferQuery, Result<TransferDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITransferRepository _transfers;
    private readonly IWarehouseRepository _warehouses;

    public GetTransferQueryHandler(
        ITenantContext tenantContext,
        ITransferRepository transfers,
        IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _transfers = transfers;
        _warehouses = warehouses;
    }

    public async Task<Result<TransferDto>> Handle(
        GetTransferQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var transfer = await _transfers.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (transfer is null)
        {
            return Error.NotFound("Transfer not found.");
        }

        var srcWh = await _warehouses.GetByIdAsync(tenantId, transfer.SourceWarehouseId, cancellationToken);
        var dstWh = await _warehouses.GetByIdAsync(tenantId, transfer.DestinationWarehouseId, cancellationToken);

        return Result.Success(WarehouseMappers.ToTransferDto(
            transfer,
            srcWh?.Name ?? "Unknown",
            dstWh?.Name ?? "Unknown",
            transfer.Lines.Select(l => new TransferLineInput(
                l.ProductId, l.VariantId, l.Quantity, l.BatchId)).ToList()));
    }
}

public sealed record ListStockCountsQuery(int Page, int PageSize)
    : IRequest<Result<PagedResult<StockCountSummaryDto>>>;

public sealed class ListStockCountsQueryHandler
    : IRequestHandler<ListStockCountsQuery, Result<PagedResult<StockCountSummaryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockCountRepository _counts;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;

    public ListStockCountsQueryHandler(
        ITenantContext tenantContext,
        IStockCountRepository counts,
        IWarehouseRepository warehouses,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _counts = counts;
        _warehouses = warehouses;
        _products = products;
    }

    public async Task<Result<PagedResult<StockCountSummaryDto>>> Handle(
        ListStockCountsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _counts.ListAsync(tenantId, query.Page, query.PageSize, cancellationToken);
        var total = await _counts.CountAsync(tenantId, cancellationToken);

        var summaries = new List<StockCountSummaryDto>();
        foreach (var c in items)
        {
            var wh = await _warehouses.GetByIdAsync(tenantId, c.WarehouseId, cancellationToken);
            var product = await _products.GetByIdAsync(tenantId, c.ProductId, cancellationToken);
            summaries.Add(new StockCountSummaryDto(
                c.Id, wh?.Name ?? "Unknown", product?.Name ?? "Unknown",
                c.CountedQuantity, c.Status, c.CreatedAt));
        }

        return Result.Success(new PagedResult<StockCountSummaryDto>(summaries, query.Page, query.PageSize, total));
    }
}

public sealed record GetStockCountQuery(Guid Id)
    : IRequest<Result<StockCountDto>>;

public sealed class GetStockCountQueryHandler
    : IRequestHandler<GetStockCountQuery, Result<StockCountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockCountRepository _counts;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;

    public GetStockCountQueryHandler(
        ITenantContext tenantContext,
        IStockCountRepository counts,
        IWarehouseRepository warehouses,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _counts = counts;
        _warehouses = warehouses;
        _products = products;
    }

    public async Task<Result<StockCountDto>> Handle(
        GetStockCountQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var count = await _counts.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (count is null)
        {
            return Error.NotFound("Stock count not found.");
        }

        var wh = await _warehouses.GetByIdAsync(tenantId, count.WarehouseId, cancellationToken);
        var product = await _products.GetByIdAsync(tenantId, count.ProductId, cancellationToken);

        return Result.Success(WarehouseMappers.ToStockCountDto(
            count, wh?.Name ?? "Unknown", product?.Name ?? "Unknown"));
    }
}

public sealed record ListStockBatchesQuery(int Page, int PageSize, Guid? ProductId)
    : IRequest<Result<PagedResult<StockBatchDto>>>;

public sealed class ListStockBatchesQueryHandler
    : IRequestHandler<ListStockBatchesQuery, Result<PagedResult<StockBatchDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockBatchRepository _batches;
    private readonly IProductRepository _products;

    public ListStockBatchesQueryHandler(
        ITenantContext tenantContext,
        IStockBatchRepository batches,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _batches = batches;
        _products = products;
    }

    public async Task<Result<PagedResult<StockBatchDto>>> Handle(
        ListStockBatchesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _batches.ListAsync(tenantId, query.Page, query.PageSize, query.ProductId, cancellationToken);
        var total = await _batches.CountAsync(tenantId, query.ProductId, cancellationToken);

        var dtos = new List<StockBatchDto>();
        foreach (var batch in items)
        {
            var product = await _products.GetByIdAsync(tenantId, batch.ProductId, cancellationToken);
            dtos.Add(WarehouseMappers.ToStockBatchDto(batch, product?.Name ?? "Unknown"));
        }

        return Result.Success(new PagedResult<StockBatchDto>(dtos, query.Page, query.PageSize, total));
    }
}

public sealed record GetStockBatchQuery(Guid Id)
    : IRequest<Result<StockBatchDto>>;

public sealed class GetStockBatchQueryHandler
    : IRequestHandler<GetStockBatchQuery, Result<StockBatchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockBatchRepository _batches;
    private readonly IProductRepository _products;

    public GetStockBatchQueryHandler(
        ITenantContext tenantContext,
        IStockBatchRepository batches,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _batches = batches;
        _products = products;
    }

    public async Task<Result<StockBatchDto>> Handle(
        GetStockBatchQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var batch = await _batches.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (batch is null)
        {
            return Error.NotFound("Stock batch not found.");
        }

        var product = await _products.GetByIdAsync(tenantId, batch.ProductId, cancellationToken);
        return Result.Success(WarehouseMappers.ToStockBatchDto(batch, product?.Name ?? "Unknown"));
    }
}
