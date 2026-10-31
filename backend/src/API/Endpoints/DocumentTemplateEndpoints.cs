using System.Text;
using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Invoicing;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class DocumentTemplateEndpoints
{
    public static IEndpointRouteBuilder MapDocumentTemplateEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var templates = api.MapGroup("/document-templates")
            .WithApiVersionSet(versionSet)
            .WithTags("DocumentTemplates")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        templates.MapGet("/", ListDocumentTemplatesAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("ListDocumentTemplates");

        templates.MapGet("/{id:guid}", GetDocumentTemplateAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("GetDocumentTemplate");

        templates.MapPost("/preview", PreviewDocumentTemplateAsync)
            .RequirePermission(PermissionNames.InvoicesManage)
            .WithName("PreviewDocumentTemplate");

        var tenantConfigs = api.MapGroup("/tenant-document-configurations")
            .WithApiVersionSet(versionSet)
            .WithTags("TenantDocumentConfigurations")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        tenantConfigs.MapGet("/", GetTenantConfigurationsAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("GetTenantDocumentConfigurations");

        tenantConfigs.MapPut("/{documentType}", UpdateTenantConfigurationAsync)
            .RequirePermission(PermissionNames.InvoicesManage)
            .WithName("UpdateTenantDocumentConfiguration");

        var invoices = api.MapGroup("/invoices")
            .WithApiVersionSet(versionSet)
            .WithTags("Invoices")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        invoices.MapGet("/{id:guid}/html", RenderInvoiceHtmlAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("RenderInvoiceHtml");

        var deliveryNotes = api.MapGroup("/delivery-notes")
            .WithApiVersionSet(versionSet)
            .WithTags("DeliveryNotes")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        deliveryNotes.MapGet("/{id:guid}/html", RenderDeliveryNoteHtmlAsync)
            .RequirePermission(PermissionNames.DeliveryNotesView)
            .WithName("RenderDeliveryNoteHtml");

        return app;
    }

    private static async Task<IResult> ListDocumentTemplatesAsync(
        DocumentType? documentType, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListDocumentTemplatesQuery(documentType), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> GetDocumentTemplateAsync(
        Guid id, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetDocumentTemplateQuery(id), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> PreviewDocumentTemplateAsync(
        PreviewTemplateRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new PreviewDocumentTemplateQuery(
                request.LiquidLayout,
                request.DocumentType,
                request.ThemePrimaryHex,
                request.LogoUrl),
            cancellationToken);

        if (result.IsFailure)
        {
            return result.ToApiResult();
        }

        return Results.Content(result.Value, "text/html; charset=utf-8", Encoding.UTF8);
    }

    private static async Task<IResult> GetTenantConfigurationsAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetTenantDocumentConfigurationsQuery(), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> UpdateTenantConfigurationAsync(
        DocumentType documentType,
        UpdateTenantDocumentConfigurationRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateTenantDocumentConfigurationCommand(
                documentType,
                request.ActiveTemplateId,
                request.CustomLiquidOverride,
                request.ThemePrimaryHex,
                request.ThemeSecondaryHex,
                request.LogoUrl,
                request.ShowLogo,
                request.FooterNotes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RenderInvoiceHtmlAsync(
        Guid id, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(new RenderInvoiceHtmlQuery(id), cancellationToken);
        if (result.IsFailure)
        {
            return result.ToApiResult();
        }

        return Results.Content(result.Value, "text/html; charset=utf-8", Encoding.UTF8);
    }

    private static async Task<IResult> RenderDeliveryNoteHtmlAsync(
        Guid id, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(new RenderDeliveryNoteHtmlQuery(id), cancellationToken);
        if (result.IsFailure)
        {
            return result.ToApiResult();
        }

        return Results.Content(result.Value, "text/html; charset=utf-8", Encoding.UTF8);
    }
}
