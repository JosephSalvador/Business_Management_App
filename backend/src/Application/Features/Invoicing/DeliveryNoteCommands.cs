using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Commands;

public static class DeliveryNoteMappers
{
    public static DeliveryNoteDto ToDto(DeliveryNote note) => new(
        note.Id,
        note.Number,
        note.InvoiceId,
        note.InvoiceNumber,
        note.CustomerId,
        note.CustomerName,
        note.CustomerAttention,
        note.CustomerPhone,
        note.DeliveryAddress,
        note.IssueDate,
        note.Status,
        note.VehicleNumber,
        note.DriverName,
        note.DriverPhone,
        note.ReceivedByName,
        note.Notes,
        note.DispatchedAtUtc,
        note.DeliveredAtUtc,
        note.CancelledAtUtc,
        note.Items
            .OrderBy(i => i.LineIndex)
            .Select(i => new DeliveryNoteItemDto(
                i.Id,
                i.ProductId,
                i.Description,
                i.UnitOfMeasure,
                i.QuantityOrdered,
                i.QuantityDelivered,
                i.LineIndex))
            .ToList(),
        note.CreatedAt);

    public static DeliveryNoteSummaryDto ToSummary(DeliveryNote note) => new(
        note.Id,
        note.Number,
        note.InvoiceId,
        note.InvoiceNumber,
        note.CustomerId,
        note.CustomerName,
        note.Status,
        note.IssueDate,
        note.Items.Count,
        note.VehicleNumber,
        note.DriverName,
        note.CreatedAt);
}

public sealed record CreateDeliveryNoteItemRequest(
    Guid? ProductId,
    string Description,
    decimal QuantityOrdered,
    decimal QuantityDelivered,
    string UnitOfMeasure = "Pcs");

public sealed record CreateDeliveryNoteCommand(
    IReadOnlyList<CreateDeliveryNoteItemRequest>? Items = null,
    Guid? InvoiceId = null,
    Guid? CustomerId = null,
    string? CustomerName = null,
    string? CustomerAttention = null,
    string? CustomerPhone = null,
    string? DeliveryAddress = null,
    DateTime? IssueDate = null,
    string? VehicleNumber = null,
    string? DriverName = null,
    string? DriverPhone = null,
    string? Notes = null,
    Guid? Id = null)
    : IRequest<Result<DeliveryNoteDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateDeliveryNoteCommandHandler
    : IRequestHandler<CreateDeliveryNoteCommand, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;
    private readonly ICustomerInvoiceRepository _invoices;
    private readonly ICustomerRepository _customers;
    private readonly IInvoiceNumberSequenceService _numbers;

    public CreateDeliveryNoteCommandHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes,
        ICustomerInvoiceRepository invoices,
        ICustomerRepository customers,
        IInvoiceNumberSequenceService numbers)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
        _invoices = invoices;
        _customers = customers;
        _numbers = numbers;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        CreateDeliveryNoteCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        if (tenantId == Guid.Empty)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.Unauthorized("AUTH_TENANT_MISSING", "Tenant context is required."));
        }

        string? invoiceNumber = null;
        var customerId = request.CustomerId;
        var customerName = request.CustomerName;
        var customerAttention = request.CustomerAttention;
        var customerPhone = request.CustomerPhone;
        var deliveryAddress = request.DeliveryAddress;

        var itemSpecs = new List<DeliveryNoteItemSpec>();

        if (request.InvoiceId.HasValue && request.InvoiceId.Value != Guid.Empty)
        {
            var invoice = await _invoices.GetByIdAsync(tenantId, request.InvoiceId.Value, cancellationToken);
            if (invoice is null)
            {
                return Result<DeliveryNoteDto>.Failure(
                    Error.NotFound("INVOICE_NOT_FOUND", $"Customer invoice '{request.InvoiceId.Value}' was not found."));
            }

            invoiceNumber = invoice.Number;
            customerId ??= invoice.CustomerId;
            customerName ??= invoice.CustomerName;
            customerAttention ??= invoice.CustomerAttention;
            customerPhone ??= invoice.CustomerPhone;
            deliveryAddress ??= invoice.CustomerAddress;

            if (request.Items is null || request.Items.Count == 0)
            {
                foreach (var line in invoice.Lines.OrderBy(l => l.OrderIndex))
                {
                    itemSpecs.Add(new DeliveryNoteItemSpec(
                        ProductId: null,
                        Description: line.Description,
                        UnitOfMeasure: line.UnitOfMeasure,
                        QuantityOrdered: line.Quantity,
                        QuantityDelivered: line.Quantity));
                }
            }
        }

        if (itemSpecs.Count == 0 && request.Items is { Count: > 0 })
        {
            foreach (var item in request.Items)
            {
                itemSpecs.Add(new DeliveryNoteItemSpec(
                    ProductId: item.ProductId,
                    Description: item.Description,
                    UnitOfMeasure: string.IsNullOrWhiteSpace(item.UnitOfMeasure) ? "Pcs" : item.UnitOfMeasure,
                    QuantityOrdered: item.QuantityOrdered,
                    QuantityDelivered: item.QuantityDelivered));
            }
        }

        if (itemSpecs.Count == 0)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.Validation("ITEMS_REQUIRED", "A delivery note must contain at least one line item."));
        }

        if (customerId.HasValue && string.IsNullOrWhiteSpace(customerName))
        {
            var customer = await _customers.GetByIdAsync(tenantId, customerId.Value, cancellationToken);
            if (customer is not null)
            {
                customerName = customer.Name;
                customerPhone ??= customer.Phone;
                deliveryAddress ??= customer.Address;
            }
        }

        var effectiveIssueDate = request.IssueDate ?? DateTime.UtcNow;
        var number = await _numbers.NextAsync(
            tenantId, DocumentKind.DeliveryNote, effectiveIssueDate, cancellationToken);

        var deliveryNote = DeliveryNote.Create(
            tenantId: tenantId,
            number: number,
            items: itemSpecs,
            invoiceId: request.InvoiceId,
            invoiceNumber: invoiceNumber,
            customerId: customerId,
            customerName: customerName,
            customerAttention: customerAttention,
            customerPhone: customerPhone,
            deliveryAddress: deliveryAddress,
            issueDate: effectiveIssueDate,
            vehicleNumber: request.VehicleNumber,
            driverName: request.DriverName,
            driverPhone: request.DriverPhone,
            notes: request.Notes,
            nowUtc: DateTime.UtcNow,
            id: request.Id);

        await _deliveryNotes.AddAsync(deliveryNote, cancellationToken);
        return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(deliveryNote));
    }
}

public sealed record MarkDeliveryNoteDispatchedCommand(
    Guid Id,
    string? VehicleNumber = null,
    string? DriverName = null,
    string? DriverPhone = null)
    : IRequest<Result<DeliveryNoteDto>>, IRequiresTenantAdvisoryLock;

public sealed class MarkDeliveryNoteDispatchedCommandHandler
    : IRequestHandler<MarkDeliveryNoteDispatchedCommand, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public MarkDeliveryNoteDispatchedCommandHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        MarkDeliveryNoteDispatchedCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, request.Id, cancellationToken);
        if (note is null)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{request.Id}' was not found."));
        }

        try
        {
            note.MarkDispatched(request.VehicleNumber, request.DriverName, request.DriverPhone);
            await _deliveryNotes.UpdateAsync(note, cancellationToken);
            return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(note));
        }
        catch (InvalidOperationException ex)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.Validation("INVALID_DELIVERY_NOTE_STATE", ex.Message));
        }
    }
}

public sealed record MarkDeliveryNoteDeliveredCommand(
    Guid Id,
    string? ReceivedByName = null)
    : IRequest<Result<DeliveryNoteDto>>, IRequiresTenantAdvisoryLock;

public sealed class MarkDeliveryNoteDeliveredCommandHandler
    : IRequestHandler<MarkDeliveryNoteDeliveredCommand, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public MarkDeliveryNoteDeliveredCommandHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        MarkDeliveryNoteDeliveredCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, request.Id, cancellationToken);
        if (note is null)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{request.Id}' was not found."));
        }

        try
        {
            note.MarkDelivered(request.ReceivedByName);
            await _deliveryNotes.UpdateAsync(note, cancellationToken);
            return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(note));
        }
        catch (InvalidOperationException ex)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.Validation("INVALID_DELIVERY_NOTE_STATE", ex.Message));
        }
    }
}

public sealed record CancelDeliveryNoteCommand(
    Guid Id,
    string? Reason = null)
    : IRequest<Result<DeliveryNoteDto>>, IRequiresTenantAdvisoryLock;

public sealed class CancelDeliveryNoteCommandHandler
    : IRequestHandler<CancelDeliveryNoteCommand, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public CancelDeliveryNoteCommandHandler(
        ITenantContext tenantContext,
        IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        CancelDeliveryNoteCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, request.Id, cancellationToken);
        if (note is null)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{request.Id}' was not found."));
        }

        try
        {
            note.Cancel(request.Reason);
            await _deliveryNotes.UpdateAsync(note, cancellationToken);
            return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(note));
        }
        catch (InvalidOperationException ex)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.Validation("INVALID_DELIVERY_NOTE_STATE", ex.Message));
        }
    }
}
