using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Tenants;

public sealed class Tenant : AggregateRoot
{
    private Tenant(Guid id, string name, string? databaseSchema) : base(id)
    {
        Name = name;
        DatabaseSchema = databaseSchema;
    }

    public string Name { get; private set; }
    public string? DatabaseSchema { get; private set; }
    public bool IsActive { get; private set; } = true;

    public static Tenant Create(Guid id, string name, string? databaseSchema = null)
        => new(id, name, databaseSchema);

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;
}
