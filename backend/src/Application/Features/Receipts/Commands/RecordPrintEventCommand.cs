using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Receipts.Commands;

/// <summary>
/// Records a receipt print event for audit trail purposes. The first print for a sale is
/// <see cref="PrintType.Original"/>; subsequent prints are <see cref="PrintType.Reprint"/>
/// or <see cref="PrintType.CustomerCopy"/>. The renderer detects reprints and injects a
/// visible "REPRINT" watermark.
/// </summary>
public sealed record RecordPrintEventCommand(
    Guid SaleId,
    PrintType Type,
    string? DeviceId = null,
    string? Notes = null)
    : IRequest<Result<Guid>>;

public sealed class RecordPrintEventCommandHandler : IRequestHandler<RecordPrintEventCommand, Result<Guid>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISaleRepository _sales;
    private readonly IReceiptMetadataRepository _metadata;
    private readonly IReceiptPrintEventRepository _printEvents;

    public RecordPrintEventCommandHandler(
        ITenantContext tenantContext,
        ISaleRepository sales,
        IReceiptMetadataRepository metadata,
        IReceiptPrintEventRepository printEvents)
    {
        _tenantContext = tenantContext;
        _sales = sales;
        _metadata = metadata;
        _printEvents = printEvents;
    }

    public async Task<Result<Guid>> Handle(RecordPrintEventCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;

        if (!userId.HasValue || userId.Value == Guid.Empty)
        {
            return Error.Unauthorized("A signed-in user is required to record a print event.");
        }

        var sale = await _sales.GetByIdAsync(tenantId, command.SaleId, cancellationToken);
        if (sale is null)
        {
            return Error.NotFound("Sale not found.");
        }

        var metadata = await _metadata.GetBySaleIdAsync(command.SaleId, cancellationToken);

        var printEvent = ReceiptPrintEvent.Create(
            saleId: command.SaleId,
            tenantId: tenantId,
            printedByUserId: userId.Value,
            type: command.Type,
            layoutVersionId: metadata?.LayoutVersionId,
            deviceId: command.DeviceId,
            notes: command.Notes);

        await _printEvents.AddAsync(printEvent, cancellationToken);
        return printEvent.Id;
    }
}
