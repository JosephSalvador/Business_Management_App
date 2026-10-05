namespace BusinessOS.Domain.Sales;

/// <summary>
/// A compact snapshot of the business identity (name, TIN, VRN, address, logo) captured at
/// the exact moment a sale is finalized. Stored alongside the receipt metadata so that
/// reprints and historical views always reflect the truth of the sale date, not the current
/// business settings which may have changed since.
/// </summary>
public sealed class BusinessIdentitySnapshot
{
    // Internal rather than private: the source-generated serializer context in this
    // assembly must be able to call the constructor (SYSLIB1222). Factory stays `Create`.
    [System.Text.Json.Serialization.JsonConstructor]
    internal BusinessIdentitySnapshot(
        string businessName,
        string? tin,
        string? vrn,
        string? address,
        string? phone,
        string? email,
        string? logoUrl,
        string? taxRegistrationNumber,
        DateTime capturedAt)
    {
        BusinessName = businessName;
        TIN = tin;
        VRN = vrn;
        Address = address;
        Phone = phone;
        Email = email;
        LogoUrl = logoUrl;
        TaxRegistrationNumber = taxRegistrationNumber;
        CapturedAt = capturedAt;
    }

    public string BusinessName { get; }
    public string? TIN { get; }
    public string? VRN { get; }
    public string? Address { get; }
    public string? Phone { get; }
    public string? Email { get; }
    public string? LogoUrl { get; }
    public string? TaxRegistrationNumber { get; }
    public DateTime CapturedAt { get; }

    public static BusinessIdentitySnapshot Create(
        string businessName,
        string? tin = null,
        string? vrn = null,
        string? address = null,
        string? phone = null,
        string? email = null,
        string? logoUrl = null,
        string? taxRegistrationNumber = null)
    {
        if (string.IsNullOrWhiteSpace(businessName))
        {
            throw new ArgumentException("A business name is required.", nameof(businessName));
        }

        return new BusinessIdentitySnapshot(
            businessName.Trim(),
            Normalize(tin),
            Normalize(vrn),
            Normalize(address),
            Normalize(phone),
            Normalize(email),
            Normalize(logoUrl),
            Normalize(taxRegistrationNumber),
            DateTime.UtcNow);
    }

    /// <summary>Serializes the snapshot to a JSON string for storage.</summary>
    public string ToJson()
        => System.Text.Json.JsonSerializer.Serialize(this, JsonContext.Default.BusinessIdentitySnapshot);

    /// <summary>Deserializes a snapshot from its stored JSON representation.</summary>
    public static BusinessIdentitySnapshot FromJson(string json)
        => System.Text.Json.JsonSerializer.Deserialize(json, JsonContext.Default.BusinessIdentitySnapshot)
           ?? throw new ArgumentException("Invalid business identity snapshot JSON.", nameof(json));

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

/// <summary>
/// JSON source generator context for <see cref="BusinessIdentitySnapshot"/> serialization.
/// Enables AOT-compatible serialization without reflection.
/// </summary>
[System.Text.Json.Serialization.JsonSerializable(typeof(BusinessIdentitySnapshot))]
internal sealed partial class JsonContext : System.Text.Json.Serialization.JsonSerializerContext
{
}
