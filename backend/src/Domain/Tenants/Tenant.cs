using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Tenants;

public sealed class Tenant : AggregateRoot
{
    public const string DefaultCurrency = "TZS";

    private Tenant(Guid id, string name, string currency, string? databaseSchema)
        : base(id)
    {
        Name = name;
        Currency = currency;
        DatabaseSchema = databaseSchema;
    }

    public string Name { get; private set; }
    public string Currency { get; private set; }
    public string? ContactEmail { get; private set; }
    public string? ContactPhone { get; private set; }
    public string? Address { get; private set; }
    public string? TaxId { get; private set; }
    public string? DatabaseSchema { get; private set; }
    public bool IsActive { get; private set; } = true;

    public static Tenant Create(Guid id, string name, string? currency = null, string? databaseSchema = null)
        => new(id, name, currency ?? DefaultCurrency, databaseSchema);

    public void UpdateProfile(string name, string? contactEmail, string? contactPhone, string? address, string? taxId)
    {
        Name = name.Trim();
        ContactEmail = contactEmail;
        ContactPhone = contactPhone;
        Address = address;
        TaxId = taxId;
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;
}
