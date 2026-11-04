using Asp.Versioning.Builder;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Invoicing.Queries;
using BusinessOS.Infrastructure.Services;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class PublicInvoiceVerificationEndpoints
{
    public static IEndpointRouteBuilder MapPublicInvoiceVerificationEndpoints(this IEndpointRouteBuilder app)
    {
        // 1. Direct short URL for QR code scanner (e.g. https://api.jolinx.org/v/{token})
        var shortGroup = app.MapGroup("/v")
            .AllowAnonymous()
            .RequireRateLimiting("global");

        shortGroup.MapGet("/{token}", ViewVerificationHtmlAsync)
            .WithName("ViewPublicInvoiceHtml")
            .WithSummary("Public, responsive HTML invoice verification page scanned via QR code.");

        shortGroup.MapGet("/{token}/pdf", DownloadVerificationPdfAsync)
            .WithName("DownloadPublicInvoicePdf")
            .WithSummary("Public PDF binary download of the verified customer invoice.");

        // 2. Versioned JSON API endpoint for external clients / integrations
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var publicApi = api.MapGroup("/public/invoices")
            .WithApiVersionSet(versionSet)
            .WithTags("PublicInvoicing")
            .AllowAnonymous()
            .RequireRateLimiting("global");

        publicApi.MapGet("/{token}", GetVerificationJsonAsync)
            .WithName("GetPublicInvoiceVerificationJson")
            .WithSummary("JSON representation of the verified invoice and issuer profile.");

        return app;
    }

    private static async Task<IResult> ViewVerificationHtmlAsync(
        string token, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(new GetPublicInvoiceVerificationQuery(token), cancellationToken);
        if (result.IsFailure || result.Value is null)
        {
            var notFoundHtml = @"<!DOCTYPE html>
<html lang=""sw"">
<head>
  <meta charset=""utf-8"" />
  <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"" />
  <meta name=""robots"" content=""noindex, nofollow"" />
  <title>Hati Haikupatikana &bull; Document Not Found</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, ""Segoe UI"", Roboto, sans-serif; background: #f8fafc; color: #0f172a; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; margin: 0; }
    .card { background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; padding: 32px 24px; max-width: 440px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05); }
    .icon { width: 56px; height: 56px; margin: 0 auto 16px auto; color: #dc2626; }
    h2 { font-size: 20px; font-weight: 700; margin-bottom: 8px; }
    p { font-size: 14px; color: #64748b; line-height: 1.5; margin-bottom: 20px; }
    .badge { display: inline-block; background: #fee2e2; color: #991b1b; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: 600; font-family: monospace; }
  </style>
</head>
<body>
  <div class=""card"">
    <svg class=""icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor"" stroke-width=""2""><circle cx=""12"" cy=""12"" r=""10""/><line x1=""12"" y1=""8"" x2=""12"" y2=""12""/><line x1=""12"" y1=""16"" x2=""12.01"" y2=""16""/></svg>
    <h2>Hati Haikupatikana</h2>
    <p>Ankara au hati uliyotaka kuikagua haikupatikana kwenye mfumo. Hakikisha umeskani kodi sahihi ya QR.</p>
    <div class=""badge"">Invalid or Expired Token</div>
  </div>
</body>
</html>";
            return Results.Content(notFoundHtml, "text/html; charset=utf-8", statusCode: 404);
        }

        var html = InvoiceVerificationHtmlRenderer.Render(result.Value);
        return Results.Content(html, "text/html; charset=utf-8");
    }

    private static async Task<IResult> DownloadVerificationPdfAsync(
        string token, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(new GetPublicInvoiceVerificationQuery(token), cancellationToken);
        if (result.IsFailure || result.Value is null)
        {
            return Results.NotFound(new { error = "Invoice not found or invalid verification token." });
        }

        var inv = result.Value;
        var items = inv.Lines
            .Select(l => (
                Description: l.Description,
                Quantity: l.Quantity % 1 == 0 ? $"{l.Quantity:0}" : $"{l.Quantity:0.##}",
                Total: $"{inv.Currency} {l.LineTotal:N2}"))
            .ToList();

        var pdfBytes = MinimalPdfGenerator.CreateDocument(
            title: inv.DocumentTitle,
            documentNumber: inv.Number,
            organizationName: inv.Organization.Name,
            customerName: inv.CustomerName ?? "Walk-in Customer",
            totalFormatted: $"{inv.Currency} {inv.TotalAmount:N2}",
            items: items,
            isThermal: false);

        var safeFileName = $"{inv.Number.Replace('/', '_')}_Verified.pdf";
        return Results.File(pdfBytes, "application/pdf", safeFileName);
    }

    private static async Task<IResult> GetVerificationJsonAsync(
        string token, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(new GetPublicInvoiceVerificationQuery(token), cancellationToken);
        return result.ToApiResult();
    }
}
