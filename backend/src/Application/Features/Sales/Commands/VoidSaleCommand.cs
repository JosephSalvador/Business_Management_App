using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Sales.Commands;

public sealed record VoidSaleCommand(Guid SaleId, string Reason)
    : IRequest<Result<SaleDto>>, IRequiresTenantAdvisoryLock;

/// <summary>
/// Voids a completed sale: the sale flips to <see cref="SaleStatus.Voided"/> and every posted
/// <see cref="StockMovementType.Sale"/> ledger row is reversed with a positive
/// <see cref="StockMovementType.SaleVoid"/> movement (stock added back). The receipt number and
/// original ledger rows stay immutable; <see cref="SaleVoidedEvent"/> is raised through the
/// outbox. A voided sale cannot be voided again.
/// </summary>
public sealed class VoidSaleCommandHandler : IRequestHandler<VoidSaleCommand, Result<SaleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISaleRepository _sales;
    private readonly IStockRepository _stock;
    private readonly SaleStockDebitService _stockDebit;

    public VoidSaleCommandHandler(
        ITenantContext tenantContext,
        ISaleRepository sales,
        IStockRepository stock,
        SaleStockDebitService stockDebit)
    {
        _tenantContext = tenantContext;
        _sales = sales;
        _stock = stock;
        _stockDebit = stockDebit;
    }

    public async Task<Result<SaleDto>> Handle(VoidSaleCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var voidedBy = _tenantContext.UserId;
        if (!voidedBy.HasValue || voidedBy.Value == Guid.Empty)
        {
            return Error.Unauthorized("A signed-in user is required to void a sale.");
        }

        var sale = await _sales.GetByIdAsync(tenantId, command.SaleId, cancellationToken);
        if (sale is null)
        {
            return Error.NotFound("Sale not found.");
        }

        if (sale.Status == SaleStatus.Voided)
        {
            return Error.Conflict("The sale has already been voided.");
        }

        var occurredAt = DateTime.UtcNow;
        var movements = await _stock.ListMovementsByReferenceAsync(
            tenantId, "Sale", sale.Id, StockMovementType.Sale, cancellationToken);

        if (movements.Count > 0)
        {
            await _stockDebit.RestoreAsync(new StockRestoreRequest(
                tenantId,
                sale.Id,
                occurredAt,
                voidedBy.Value,
                command.Reason,
                movements),
                cancellationToken);
        }

        sale.Void(command.Reason, voidedBy.Value, occurredAt);
        await _sales.UpdateAsync(sale, cancellationToken);

        return Result.Success(SalesMappers.ToDto(sale));
    }
}
