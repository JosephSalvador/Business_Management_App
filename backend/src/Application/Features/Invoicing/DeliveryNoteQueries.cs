using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Queries;

// ── List Delivery Notes ──────────────────────────────────────────────
public sealed record ListDeliveryNotesQuery(
    int Page,
    int PageSize,
    DeliveryNoteStatus? Status = null,
    Guid? InvoiceId = null,
    string? Search = null)
    : IRequest<Result<PagedResult<DeliveryNoteSummaryDto>>>;

public sealed class ListDeliveryNotesQueryHandler
    : IRequestHandler<ListDeliveryNotesQuery, Result<PagedResult<DeliveryNoteSummaryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public ListDeliveryNotesQueryHandler(
        ITenantContext tenantContext, IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<PagedResult<DeliveryNoteSummaryDto>>> Handle(
        ListDeliveryNotesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var page = query.Page <= 0 ? 1 : query.Page;
        var pageSize = query.PageSize <= 0 ? 20 : (query.PageSize > 100 ? 100 : query.PageSize);

        var filter = new DeliveryNoteListFilter(query.Status, query.InvoiceId, query.Search);
        var items = await _deliveryNotes.ListAsync(
            tenantId, page, pageSize, filter, cancellationToken);
        var total = await _deliveryNotes.CountAsync(tenantId, filter, cancellationToken);

        return Result.Success(new PagedResult<DeliveryNoteSummaryDto>(
            items.Select(DeliveryNoteMappers.ToSummary).ToList(),
            page,
            pageSize,
            total));
    }
}

// ── Get Delivery Note ────────────────────────────────────────────────
public sealed record GetDeliveryNoteQuery(Guid Id)
    : IRequest<Result<DeliveryNoteDto>>;

public sealed class GetDeliveryNoteQueryHandler
    : IRequestHandler<GetDeliveryNoteQuery, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public GetDeliveryNoteQueryHandler(
        ITenantContext tenantContext, IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        GetDeliveryNoteQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByIdAsync(tenantId, query.Id, cancellationToken);
        if (note is null)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{query.Id}' was not found."));
        }

        return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(note));
    }
}

// ── Get Delivery Note by Number ──────────────────────────────────────
public sealed record GetDeliveryNoteByNumberQuery(string Number)
    : IRequest<Result<DeliveryNoteDto>>;

public sealed class GetDeliveryNoteByNumberQueryHandler
    : IRequestHandler<GetDeliveryNoteByNumberQuery, Result<DeliveryNoteDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDeliveryNoteRepository _deliveryNotes;

    public GetDeliveryNoteByNumberQueryHandler(
        ITenantContext tenantContext, IDeliveryNoteRepository deliveryNotes)
    {
        _tenantContext = tenantContext;
        _deliveryNotes = deliveryNotes;
    }

    public async Task<Result<DeliveryNoteDto>> Handle(
        GetDeliveryNoteByNumberQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var note = await _deliveryNotes.GetByNumberAsync(tenantId, query.Number, cancellationToken);
        if (note is null)
        {
            return Result<DeliveryNoteDto>.Failure(
                Error.NotFound("DELIVERY_NOTE_NOT_FOUND", $"Delivery note '{query.Number}' was not found."));
        }

        return Result<DeliveryNoteDto>.Success(DeliveryNoteMappers.ToDto(note));
    }
}
