using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

public sealed class Warehouse : AggregateRoot
{
    public const string DefaultLocationCode = "MAIN";
    public const string DefaultLocationName = "Main";

    private readonly List<StockLocation> _locations = new();

    private Warehouse(
        Guid id,
        Guid tenantId,
        Guid branchId,
        string name,
        string code,
        string? description)
        : base(id)
    {
        TenantId = tenantId;
        BranchId = branchId;
        Name = name;
        Code = code;
        Description = description;
    }

    public Guid TenantId { get; private set; }
    public Guid BranchId { get; private set; }
    public string Name { get; private set; }
    public string Code { get; private set; }
    public string? Description { get; private set; }
    public bool IsActive { get; private set; } = true;

    public IReadOnlyCollection<StockLocation> Locations => _locations.AsReadOnly();

    public static Warehouse Create(
        Guid tenantId,
        Guid branchId,
        string name,
        string code,
        string? description = null)
    {
        var warehouse = new Warehouse(
            Guid.NewGuid(),
            tenantId,
            branchId,
            name.Trim(),
            NormalizeCode(code),
            description);

        warehouse._locations.Add(StockLocation.Assign(
            tenantId, warehouse.Id, Guid.Empty, DefaultLocationCode, DefaultLocationName, isActive: true));

        warehouse.AddDomainEvent(new WarehouseCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, warehouse.Id, tenantId, branchId, warehouse.Name, warehouse.Code));

        return warehouse;
    }

    public static string NormalizeCode(string code) => code.Trim().ToUpperInvariant();

    public void UpdateProfile(string name, string? description)
    {
        Name = name.Trim();
        Description = description;

        AddDomainEvent(new WarehouseUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name, Code));
    }

    public void Activate()
    {
        if (IsActive)
        {
            return;
        }

        IsActive = true;
        AddDomainEvent(new WarehouseStatusChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name, Code, IsActive));
    }

    public void Deactivate()
    {
        if (!IsActive)
        {
            return;
        }

        IsActive = false;
        AddDomainEvent(new WarehouseStatusChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name, Code, IsActive));
    }

    public void SetLocations(IEnumerable<StockLocationSpec> locations)
    {
        var specs = locations.ToList();

        if (specs.Select(s => NormalizeCode(s.Code)).Distinct().Count() != specs.Count)
        {
            throw new ArgumentException("Location codes must be unique.", nameof(locations));
        }

        if (HasSameLocations(specs))
        {
            return;
        }

        var kept = new List<StockLocation>();
        foreach (var spec in specs)
        {
            var code = NormalizeCode(spec.Code);
            var name = spec.Name.Trim();

            var existing = _locations.FirstOrDefault(l =>
                (spec.Id != Guid.Empty && l.Id == spec.Id) || l.Code == code);
            if (existing is null)
            {
                kept.Add(StockLocation.Assign(TenantId, Id, Guid.Empty, code, name, isActive: true));
                continue;
            }

            existing.Rename(code, name);
            kept.Add(existing);
        }

        foreach (var dropped in _locations.Except(kept).ToList())
        {
            _locations.Remove(dropped);
        }

        _locations.Clear();
        _locations.AddRange(kept);

        AddDomainEvent(new WarehouseUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name, Code));
    }

    private bool HasSameLocations(IReadOnlyCollection<StockLocationSpec> specs)
    {
        if (specs.Count != _locations.Count)
        {
            return false;
        }

        foreach (var spec in specs)
        {
            var code = NormalizeCode(spec.Code);
            var name = spec.Name.Trim();

            var match = _locations.FirstOrDefault(l =>
                (spec.Id != Guid.Empty && l.Id == spec.Id) || l.Code == code);
            if (match is null || match.Name != name)
            {
                return false;
            }
        }

        return true;
    }
}
