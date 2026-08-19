using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

public sealed class Account : Entity
{
    private Account(Guid id, Guid tenantId, string code, string name, AccountType type) : base(id)
    {
        TenantId = tenantId;
        Code = code;
        Name = name;
        Type = type;
        IsActive = true;
    }

    public Guid TenantId { get; private set; }
    public string Code { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public AccountType Type { get; private set; }
    public bool IsActive { get; private set; }

    public static Account Create(Guid tenantId, string code, string name, AccountType type, Guid? id = null)
    {
        return new Account(id ?? Guid.NewGuid(), tenantId, code.Trim(), name.Trim(), type);
    }

    public void UpdateDetails(string name, AccountType type)
    {
        Name = name.Trim();
        Type = type;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Deactivate()
    {
        IsActive = false;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Activate()
    {
        IsActive = true;
        UpdatedAt = DateTime.UtcNow;
    }
}
