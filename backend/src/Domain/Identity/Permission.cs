using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public sealed class Permission : Entity
{
    private Permission(Guid id, string name, string? description)
        : base(id)
    {
        Name = name;
        Description = description;
    }

    public string Name { get; private set; }
    public string? Description { get; private set; }

    public static Permission Create(string name, string? description = null)
        => new(Guid.NewGuid(), name, description);

    public static Permission Seed(string name, string? description = null)
        => new(Guid.NewGuid(), name, description);
}
