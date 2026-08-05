using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public sealed class Role : AggregateRoot
{
    private readonly List<Permission> _permissions = new();

    private Role(Guid id, Guid tenantId, string name)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public bool IsSystem { get; private set; }
    public IReadOnlyCollection<Permission> Permissions => _permissions.AsReadOnly();

    public static Role Create(Guid tenantId, string name, bool isSystem = false)
    {
        var role = new Role(Guid.NewGuid(), tenantId, name)
        {
            IsSystem = isSystem,
        };
        return role;
    }

    public void Grant(IEnumerable<Permission> permissions)
    {
        foreach (var permission in permissions)
        {
            if (!_permissions.Any(p => p.Name == permission.Name))
            {
                _permissions.Add(permission);
            }
        }
    }
}
