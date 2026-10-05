using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Receipts.Commands;
using BusinessOS.Application.Features.Receipts.Dtos;
using BusinessOS.Application.Features.Receipts.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Sales;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class ReceiptEndpoints
{
    public static IEndpointRouteBuilder MapReceiptEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var receipts = api.MapGroup("/receipts")
            .WithApiVersionSet(versionSet)
            .WithTags("Receipts")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        receipts.MapGet("/{saleId:guid}/preview", GetReceiptPreviewAsync)
            .RequirePermission(PermissionNames.ReceiptsView)
            .WithName("GetReceiptPreview");

        receipts.MapPost("/{saleId:guid}/print", RecordPrintEventAsync)
            .RequirePermission(PermissionNames.ReceiptsPrint)
            .WithName("RecordPrintEvent");

        receipts.MapPost("/layouts/seed", SeedDefaultLayoutAsync)
            .RequirePermission(PermissionNames.ReceiptsManageLayouts)
            .WithName("SeedDefaultLayout");

        receipts.MapGet("/layouts", ListLayoutsAsync)
            .RequirePermission(PermissionNames.ReceiptsView)
            .WithName("ListReceiptLayouts");

        return app;
    }

    private static async Task<IResult> GetReceiptPreviewAsync(
        Guid saleId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetReceiptPreviewQuery(saleId), cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordPrintEventAsync(
        Guid saleId,
        RecordPrintEventRequest request,
        ISender sender,
        CancellationToken cancellationToken)
    {
        var type = (PrintType)request.Type;
        var eventId = await sender.Send(
            new RecordPrintEventCommand(saleId, type, request.DeviceId, request.Notes),
            cancellationToken);

        return eventId.ToApiResult();
    }

    private static async Task<IResult> SeedDefaultLayoutAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SeedDefaultLayoutCommand(), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListLayoutsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListReceiptLayoutsQuery(), cancellationToken)).ToApiResult();
}
