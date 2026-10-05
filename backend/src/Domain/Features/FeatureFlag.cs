using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Features;

public sealed class FeatureFlag : AggregateRoot
{
    private FeatureFlag(Guid id, Guid tenantId, string key, bool isEnabled)
        : base(id)
    {
        TenantId = tenantId;
        Key = key;
        IsEnabled = isEnabled;
    }

    public Guid TenantId { get; private set; }
    public string Key { get; private set; }
    public bool IsEnabled { get; private set; }
    public string? Config { get; private set; }

    public static FeatureFlag Create(Guid tenantId, string key, bool isEnabled = false)
    {
        var flag = new FeatureFlag(Guid.NewGuid(), tenantId, key, isEnabled);
        if (isEnabled)
        {
            flag.RaiseChanged();
        }

        return flag;
    }

    public void Enable(string? config = null)
    {
        IsEnabled = true;
        Config = config;
        RaiseChanged();
    }

    public void Disable()
    {
        IsEnabled = false;
        Config = null;
        RaiseChanged();
    }

    private void RaiseChanged()
        => AddDomainEvent(new FeatureFlagChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Key, IsEnabled));
}
