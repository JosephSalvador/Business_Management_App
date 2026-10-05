using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// Immutable receipt metadata captured at sale finalization time. Links a sale to the exact
/// layout version and business identity that were in effect when the receipt was issued.
/// When reprinting, the renderer rebuilds the receipt exclusively from this frozen metadata
/// and the sale snapshot — ignoring any subsequent global changes (e.g. if the store's name
/// or logo changes after the sale).
/// </summary>
public sealed class ReceiptMetadata : Entity
{
    private ReceiptMetadata(
        Guid saleId,
        Guid layoutVersionId,
        string businessIdentitySnapshot,
        string? fiscalHash,
        string? fiscalSignatureAlgorithm,
        string? canonicalPayloadHash)
    {
        SaleId = saleId;
        LayoutVersionId = layoutVersionId;
        BusinessIdentitySnapshot = businessIdentitySnapshot;
        FiscalHash = fiscalHash;
        FiscalSignatureAlgorithm = fiscalSignatureAlgorithm;
        CanonicalPayloadHash = canonicalPayloadHash;
    }

    public Guid SaleId { get; private set; }
    public Guid LayoutVersionId { get; private set; }

    /// <summary>
    /// JSON-serialized <see cref="BusinessIdentitySnapshot"/> captured at sale time.
    /// Never re-read from live tenant settings.
    /// </summary>
    public string BusinessIdentitySnapshot { get; private set; }

    /// <summary>Optional fiscal hash (SHA-256 or RSA signature) for compliance jurisdictions.</summary>
    public string? FiscalHash { get; private set; }

    /// <summary>Algorithm used to compute <see cref="FiscalHash"/> (e.g. "SHA256", "RSA-SHA256").</summary>
    public string? FiscalSignatureAlgorithm { get; private set; }

    /// <summary>Hash of the canonical JSON payload, used to verify receipt integrity.</summary>
    public string? CanonicalPayloadHash { get; private set; }

    public static ReceiptMetadata Create(
        Guid saleId,
        Guid layoutVersionId,
        BusinessIdentitySnapshot identity)
    {
        if (saleId == Guid.Empty)
        {
            throw new ArgumentException("A sale is required.", nameof(saleId));
        }

        if (layoutVersionId == Guid.Empty)
        {
            throw new ArgumentException("A layout version is required.", nameof(layoutVersionId));
        }

        if (identity is null)
        {
            throw new ArgumentException("A business identity snapshot is required.", nameof(identity));
        }

        return new ReceiptMetadata(
            saleId,
            layoutVersionId,
            identity.ToJson(),
            fiscalHash: null,
            fiscalSignatureAlgorithm: null,
            canonicalPayloadHash: null);
    }

    /// <summary>
    /// Updates the fiscal fields after the fiscal adapter processes the sale.
    /// Called by the async outbox consumer, not by the core sale path.
    /// </summary>
    public void SetFiscalData(string fiscalHash, string algorithm, string? canonicalHash = null)
    {
        FiscalHash = fiscalHash ?? throw new ArgumentException("A fiscal hash is required.", nameof(fiscalHash));
        FiscalSignatureAlgorithm = algorithm ?? throw new ArgumentException("An algorithm is required.", nameof(algorithm));
        CanonicalPayloadHash = canonicalHash;
    }

    internal void AttachToSale(Guid saleId) => SaleId = saleId;
}
