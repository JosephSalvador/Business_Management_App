using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;

namespace BusinessOS.Application.Features.Receipts.Services;

/// <summary>
/// Captures and persists receipt metadata (business identity snapshot + layout version) at
/// sale finalization time. The identity is frozen from live tenant settings so that historical
/// reprints always reflect the truth of the sale date, not the current settings.
/// </summary>
public interface IReceiptMetadataService
{
    Task<ReceiptMetadata> CaptureMetadataAsync(Sale sale, CancellationToken cancellationToken);
    Task<BusinessIdentitySnapshot> GetBusinessIdentityAsync(Guid tenantId, CancellationToken cancellationToken);
}

public sealed class ReceiptMetadataService : IReceiptMetadataService
{
    private readonly ITenantRepository _tenants;
    private readonly IReceiptLayoutRepository _layouts;
    private readonly IReceiptMetadataRepository _metadata;
    private const string DefaultLayoutId = "thermal_80mm_default";

    public ReceiptMetadataService(
        ITenantRepository tenants,
        IReceiptLayoutRepository layouts,
        IReceiptMetadataRepository metadata)
    {
        _tenants = tenants;
        _layouts = layouts;
        _metadata = metadata;
    }

    public async Task<ReceiptMetadata> CaptureMetadataAsync(Sale sale, CancellationToken cancellationToken)
    {
        var identity = await GetBusinessIdentityAsync(sale.TenantId, cancellationToken);
        var layout = await _layouts.GetActiveAsync(sale.TenantId, DefaultLayoutId, cancellationToken);

        if (layout is null)
        {
            throw new InvalidOperationException(
                $"No active receipt layout '{DefaultLayoutId}' found for tenant {sale.TenantId}. " +
                "Seed the default layout before creating sales.");
        }

        var receiptMetadata = ReceiptMetadata.Create(sale.Id, layout.Id, identity);
        await _metadata.AddAsync(receiptMetadata, cancellationToken);
        return receiptMetadata;
    }

    public async Task<BusinessIdentitySnapshot> GetBusinessIdentityAsync(
        Guid tenantId, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(tenantId, cancellationToken);
        if (tenant is null)
        {
            throw new InvalidOperationException($"Tenant {tenantId} not found.");
        }

        return BusinessIdentitySnapshot.Create(
            businessName: tenant.Name,
            tin: tenant.TaxId,
            address: tenant.Address,
            phone: tenant.ContactPhone,
            email: tenant.ContactEmail);
    }
}
