using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Application.Ports;

public interface IDocumentTemplateRenderService
{
    Task<string> RenderInvoiceHtmlAsync(
        Guid tenantId,
        CustomerInvoiceDto invoice,
        TenantOrganizationDto organization,
        CancellationToken cancellationToken = default);

    Task<string> RenderDeliveryNoteHtmlAsync(
        Guid tenantId,
        DeliveryNoteDto deliveryNote,
        TenantOrganizationDto organization,
        CancellationToken cancellationToken = default);

    Task<string> RenderPreviewHtmlAsync(
        string liquidLayout,
        DocumentType documentType,
        string? themePrimaryHex,
        string? logoUrl,
        CancellationToken cancellationToken = default);
}
