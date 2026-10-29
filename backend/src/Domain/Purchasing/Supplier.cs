using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Purchasing;

public sealed class Supplier : AggregateRoot
{
    private Supplier(
        Guid id,
        Guid tenantId,
        string name,
        string? contactName,
        string? email,
        string? phone,
        string? address,
        string? tin,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        ContactName = contactName;
        Email = email;
        Phone = phone;
        Address = address;
        Tin = tin;
        Notes = notes;
        IsActive = true;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public string? ContactName { get; private set; }
    public string? Email { get; private set; }
    public string? Phone { get; private set; }
    public string? Address { get; private set; }
    public string? Tin { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public static Supplier Create(
        Guid tenantId,
        string name,
        string? contactName = null,
        string? email = null,
        string? phone = null,
        string? address = null,
        string? tin = null,
        string? notes = null,
        Guid? id = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Supplier name is required.", nameof(name));
        }

        return new Supplier(
            id.HasValue && id.Value != Guid.Empty ? id.Value : Guid.NewGuid(),
            tenantId,
            name.Trim(),
            contactName?.Trim(),
            email?.Trim(),
            phone?.Trim(),
            address?.Trim(),
            tin?.Trim(),
            notes?.Trim());
    }

    public void Activate()
    {
        IsActive = true;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Deactivate()
    {
        IsActive = false;
        UpdatedAt = DateTime.UtcNow;
    }

    public void UpdateDetails(
        string? contactName = null,
        string? email = null,
        string? phone = null,
        string? address = null,
        string? tin = null,
        string? notes = null)
    {
        ContactName = contactName?.Trim();
        Email = email?.Trim();
        Phone = phone?.Trim();
        Address = address?.Trim();
        Tin = tin?.Trim();
        Notes = notes?.Trim();
        UpdatedAt = DateTime.UtcNow;
    }
}
