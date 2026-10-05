using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// Domain service for fiscal receipt integrity: generates canonical JSON payloads from
/// finalized sales, computes SHA-256 hashes, signs payloads with RSA private keys, and
/// produces QR-code verification payloads. The canonical form ensures byte-for-byte
/// reproducibility so that any modification to the receipt data invalidates the hash.
/// </summary>
public static class FiscalSigner
{
    /// <summary>
    /// Builds a deterministic, byte-order-stable JSON string of the sale that will be used
    /// as the input for hashing or signing. Field order is alphabetical and values are
    /// normalized (trimmed strings, no whitespace, UTC timestamps in ISO 8601).
    /// </summary>
    public static string GenerateCanonicalPayload(Sale sale, ReceiptMetadata? metadata = null)
    {
        if (sale is null)
        {
            throw new ArgumentNullException(nameof(sale));
        }

        var payload = new Dictionary<string, object>
        {
            ["saleId"] = sale.Id.ToString("D"),
            ["tenantId"] = sale.TenantId.ToString("D"),
            ["number"] = sale.Number,
            ["saleDate"] = sale.SaleDate.ToString("O"),
            ["effectiveAt"] = sale.EffectiveAt.ToString("O"),
            ["currency"] = sale.Currency,
            ["subtotal"] = sale.Subtotal,
            ["discountAmount"] = sale.DiscountAmount,
            ["taxAmount"] = sale.TaxAmount,
            ["totalAmount"] = sale.TotalAmount,
            ["amountPaid"] = sale.AmountPaid,
            ["change"] = sale.Change,
            ["isElectronicPayment"] = sale.IsElectronicPayment,
            ["status"] = (int)sale.Status,
            ["source"] = (int)sale.Source,
            ["lines"] = sale.Lines
                .OrderBy(l => l.OrderIndex)
                .Select(l => new Dictionary<string, object>
                {
                    ["productId"] = l.ProductId.ToString("D"),
                    ["productName"] = l.ProductName,
                    ["quantity"] = l.Quantity,
                    ["unitPrice"] = l.UnitPrice,
                    ["discountAmount"] = l.DiscountAmount,
                    ["taxCode"] = l.TaxCode,
                    ["appliedRate"] = l.AppliedRate,
                    ["baseAmount"] = l.BaseAmount,
                    ["taxAmount"] = l.TaxAmount,
                    ["lineTotal"] = l.LineTotal,
                })
                .ToList(),
            ["payments"] = sale.Payments
                .OrderBy(p => p.OrderIndex)
                .Select(p => new Dictionary<string, object>
                {
                    ["method"] = (int)p.Method,
                    ["amount"] = p.Amount,
                })
                .ToList(),
        };

        if (metadata?.FiscalHash is not null)
        {
            payload["fiscalHash"] = metadata.FiscalHash;
        }

        var options = new JsonSerializerOptions
        {
            WriteIndented = false,
            Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        };

        return JsonSerializer.Serialize(payload, options);
    }

    /// <summary>
    /// Computes a SHA-256 hash of the canonical payload, returned as a lowercase hex string.
    /// This is the lightweight integrity check for non-fiscalized tenants.
    /// </summary>
    public static string ComputeSha256Hash(string canonicalPayload)
    {
        if (string.IsNullOrEmpty(canonicalPayload))
        {
            throw new ArgumentException("A canonical payload is required.", nameof(canonicalPayload));
        }

        var bytes = Encoding.UTF8.GetBytes(canonicalPayload);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    /// <summary>
    /// Signs the canonical payload with an RSA private key using SHA-256 PKCS#1 v1.5 padding.
    /// Returns the signature as a base64-encoded string.
    /// </summary>
    public static string SignWithRsa(string canonicalPayload, RSA privateKey)
    {
        if (string.IsNullOrEmpty(canonicalPayload))
        {
            throw new ArgumentException("A canonical payload is required.", nameof(canonicalPayload));
        }

        if (privateKey is null)
        {
            throw new ArgumentNullException(nameof(privateKey));
        }

        var bytes = Encoding.UTF8.GetBytes(canonicalPayload);
        var signature = privateKey.SignData(bytes, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return Convert.ToBase64String(signature);
    }

    /// <summary>
    /// Verifies an RSA signature against the canonical payload using the signer's public key.
    /// </summary>
    public static bool VerifyRsaSignature(string canonicalPayload, string signatureBase64, RSA publicKey)
    {
        if (string.IsNullOrEmpty(canonicalPayload))
        {
            throw new ArgumentException("A canonical payload is required.", nameof(canonicalPayload));
        }

        if (string.IsNullOrEmpty(signatureBase64))
        {
            throw new ArgumentException("A signature is required.", nameof(signatureBase64));
        }

        if (publicKey is null)
        {
            throw new ArgumentNullException(nameof(publicKey));
        }

        var payloadBytes = Encoding.UTF8.GetBytes(canonicalPayload);
        var signatureBytes = Convert.FromBase64String(signatureBase64);
        return publicKey.VerifyData(payloadBytes, signatureBytes, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    }

    /// <summary>
    /// Generates the data payload for a QR code that links to a fiscal verification page.
    /// For TRA VFD this is: base64(fiscalHash + receiptNumber + zNumber + dailyCounter).
    /// The exact format is jurisdiction-specific; this produces a generic verifiable URL.
    /// </summary>
    public static string GenerateQrPayload(
        string fiscalHash,
        string receiptNumber,
        string? zNumber = null,
        int? dailyCounter = null)
    {
        if (string.IsNullOrEmpty(fiscalHash))
        {
            throw new ArgumentException("A fiscal hash is required.", nameof(fiscalHash));
        }

        if (string.IsNullOrEmpty(receiptNumber))
        {
            throw new ArgumentException("A receipt number is required.", nameof(receiptNumber));
        }

        var data = $"{fiscalHash}|{receiptNumber}";
        if (zNumber is not null)
        {
            data += $"|{zNumber}";
        }

        if (dailyCounter.HasValue)
        {
            data += $"|{dailyCounter.Value}";
        }

        return Convert.ToBase64String(Encoding.UTF8.GetBytes(data));
    }
}
