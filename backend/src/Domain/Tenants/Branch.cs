using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Tenants;

public sealed class Branch : AggregateRoot
{
    public const string DefaultName = "Head Office";
    public const string DefaultCode = "HQ";

    private Branch(
        Guid id,
        Guid tenantId,
        string name,
        string code,
        string currency,
        string? address,
        string? phone,
        string? email)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        Code = code;
        Currency = currency;
        Address = address;
        Phone = phone;
        Email = email;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public string Code { get; private set; }
    public string Currency { get; private set; }
    public string? Address { get; private set; }
    public string? Phone { get; private set; }
    public string? Email { get; private set; }
    public bool IsActive { get; private set; } = true;

    public static Branch Create(
        Guid tenantId,
        string name,
        string code,
        string currency,
        string? address = null,
        string? phone = null,
        string? email = null)
    {
        var branch = new Branch(
            Guid.NewGuid(),
            tenantId,
            name.Trim(),
            NormalizeCode(code),
            currency,
            address,
            phone,
            email);

        branch.AddDomainEvent(new BranchCreatedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            branch.Id,
            tenantId,
            branch.Name,
            branch.Code));

        return branch;
    }

    public static string NormalizeCode(string code) => code.Trim().ToUpperInvariant();

    public void UpdateProfile(string name, string? address, string? phone, string? email)
    {
        Name = name.Trim();
        Address = address;
        Phone = phone;
        Email = email;

        AddDomainEvent(new BranchUpdatedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            Id,
            TenantId,
            Name,
            Code));
    }

    public void Activate()
    {
        IsActive = true;
        AddDomainEvent(new BranchStatusChangedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            Id,
            TenantId,
            Name,
            Code,
            IsActive));
    }

    public void Deactivate()
    {
        IsActive = false;
        AddDomainEvent(new BranchStatusChangedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            Id,
            TenantId,
            Name,
            Code,
            IsActive));
    }
}
