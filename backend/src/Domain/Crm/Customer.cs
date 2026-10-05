using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Crm;

public sealed class Customer : AggregateRoot
{
    private Customer(
        Guid id,
        Guid tenantId,
        string name,
        string? contactName,
        string? email,
        string? phone,
        string? address,
        string? tin,
        bool isVatRegistered,
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
        IsVatRegistered = isVatRegistered;
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
    public bool IsVatRegistered { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public static Customer Create(
        Guid tenantId,
        string name,
        string? contactName = null,
        string? email = null,
        string? phone = null,
        string? address = null,
        string? tin = null,
        bool isVatRegistered = false,
        string? notes = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Customer name is required.", nameof(name));
        }

        return new Customer(
            Guid.NewGuid(),
            tenantId,
            name.Trim(),
            contactName?.Trim(),
            email?.Trim(),
            phone?.Trim(),
            address?.Trim(),
            tin?.Trim(),
            isVatRegistered,
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
        string? name = null,
        string? contactName = null,
        string? email = null,
        string? phone = null,
        string? address = null,
        string? tin = null,
        bool? isVatRegistered = null,
        string? notes = null)
    {
        if (name != null) Name = name.Trim();
        ContactName = contactName?.Trim();
        Email = email?.Trim();
        Phone = phone?.Trim();
        Address = address?.Trim();
        Tin = tin?.Trim();
        if (isVatRegistered.HasValue) IsVatRegistered = isVatRegistered.Value;
        Notes = notes?.Trim();
        UpdatedAt = DateTime.UtcNow;
    }
}
