using BusinessOS.Domain.Events;
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
    public string? Description { get; private set; }
    public bool IsSystem { get; private set; }
    public IReadOnlyCollection<Permission> Permissions => _permissions.AsReadOnly();

    public static Role Create(Guid tenantId, string name, bool isSystem = false, string? description = null)
    {
        var role = new Role(Guid.NewGuid(), tenantId, name)
        {
            IsSystem = isSystem,
            Description = description,
        };
        role.AddDomainEvent(new RoleCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, role.Id, tenantId, name));
        return role;
    }

    public Role Clone()
    {
        var copy = new Role(Guid.NewGuid(), TenantId, Name)
        {
            IsSystem = false,
            Description = Description,
        };
        copy.Grant(_permissions);
        return copy;
    }

    public void Rename(string name, string? description)
    {
        Name = name.Trim();
        Description = description;

        AddDomainEvent(new RoleUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name));
    }

    public void SetPermissions(IEnumerable<Permission> permissions)
    {
        var assigned = permissions.ToList();
        _permissions.Clear();
        _permissions.AddRange(assigned);

        AddDomainEvent(new RolePermissionsChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, assigned.Select(p => p.Name).ToArray()));
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

    public void Delete()
    {
        AddDomainEvent(new RoleDeletedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name));
    }
}
