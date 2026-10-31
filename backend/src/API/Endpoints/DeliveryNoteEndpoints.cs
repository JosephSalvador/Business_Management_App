using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Invoicing;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class DeliveryNoteEndpoints
{
    public static IEndpointRouteBuilder MapDeliveryNoteEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var deliveryNotes = api.MapGroup("/delivery-notes")
            .WithApiVersionSet(versionSet)
            .WithTags("DeliveryNotes")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        deliveryNotes.MapGet("/", ListDeliveryNotesAsync)
            .RequirePermission(PermissionNames.DeliveryNotesView)
            .WithName("ListDeliveryNotes");
        deliveryNotes.MapGet("/{deliveryNoteId:guid}", GetDeliveryNoteAsync)
            .RequirePermission(PermissionNames.DeliveryNotesView)
            .WithName("GetDeliveryNote");
        deliveryNotes.MapPost("/", CreateDeliveryNoteAsync)
            .RequirePermission(PermissionNames.DeliveryNotesCreate)
            .WithName("CreateDeliveryNote");
        deliveryNotes.MapPost("/{deliveryNoteId:guid}/dispatch", DispatchDeliveryNoteAsync)
            .RequirePermission(PermissionNames.DeliveryNotesManage)
            .WithName("DispatchDeliveryNote");
        deliveryNotes.MapPost("/{deliveryNoteId:guid}/deliver", DeliverDeliveryNoteAsync)
            .RequirePermission(PermissionNames.DeliveryNotesManage)
            .WithName("DeliverDeliveryNote");
        deliveryNotes.MapPost("/{deliveryNoteId:guid}/cancel", CancelDeliveryNoteAsync)
            .RequirePermission(PermissionNames.DeliveryNotesManage)
            .WithName("CancelDeliveryNote");

        return app;
    }

    private static async Task<IResult> ListDeliveryNotesAsync(
        int? page,
        int? pageSize,
        DeliveryNoteStatus? status,
        Guid? invoiceId,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListDeliveryNotesQuery(
                page ?? 1,
                pageSize ?? 20,
                status,
                invoiceId,
                search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetDeliveryNoteAsync(
        Guid deliveryNoteId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetDeliveryNoteQuery(deliveryNoteId), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> CreateDeliveryNoteAsync(
        CreateDeliveryNoteRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateDeliveryNoteCommand(
                request.Items,
                request.InvoiceId,
                request.CustomerId,
                request.CustomerName,
                request.CustomerAttention,
                request.CustomerPhone,
                request.DeliveryAddress,
                request.IssueDate,
                request.VehicleNumber,
                request.DriverName,
                request.DriverPhone,
                request.Notes,
                request.Id),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> DispatchDeliveryNoteAsync(
        Guid deliveryNoteId,
        DispatchDeliveryNoteRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new MarkDeliveryNoteDispatchedCommand(
                deliveryNoteId,
                request.VehicleNumber,
                request.DriverName,
                request.DriverPhone),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> DeliverDeliveryNoteAsync(
        Guid deliveryNoteId,
        DeliverDeliveryNoteRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new MarkDeliveryNoteDeliveredCommand(
                deliveryNoteId,
                request.ReceivedByName),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> CancelDeliveryNoteAsync(
        Guid deliveryNoteId,
        CancelDeliveryNoteRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CancelDeliveryNoteCommand(
                deliveryNoteId,
                request.Reason),
            cancellationToken)).ToApiResult();

    private sealed record CreateDeliveryNoteRequest(
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
        Guid? Id = null);

    private sealed record DispatchDeliveryNoteRequest(
        string? VehicleNumber = null,
        string? DriverName = null,
        string? DriverPhone = null);

    private sealed record DeliverDeliveryNoteRequest(
        string? ReceivedByName = null);

    private sealed record CancelDeliveryNoteRequest(
        string? Reason = null);
}
