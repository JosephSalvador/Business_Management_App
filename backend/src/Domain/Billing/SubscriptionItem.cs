using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

public sealed class SubscriptionItem : AggregateRoot
{
    private SubscriptionItem(Guid id, Guid tenantId, string planCode)
        : base(id)
    {
        TenantId = tenantId;
        PlanCode = planCode;
    }

    public Guid TenantId { get; private set; }
    public string PlanCode { get; private set; }

    public static SubscriptionItem Create(
        Guid tenantId, string planCode, DateTime? nowUtc = null)
    {
        if (string.IsNullOrWhiteSpace(planCode))
        {
            throw new ArgumentException("Plan code is required.", nameof(planCode));
        }

        var now = nowUtc ?? DateTime.UtcNow;
        var item = new SubscriptionItem(Guid.NewGuid(), tenantId, planCode.Trim());
        item.AddDomainEvent(new SubscriptionPackageActivatedEvent(
            Guid.NewGuid(), now, item.Id, tenantId, item.PlanCode));
        return item;
    }

    public void Remove(DateTime? nowUtc = null)
    {
        var now = nowUtc ?? DateTime.UtcNow;
        AddDomainEvent(new SubscriptionPackageRemovedEvent(
            Guid.NewGuid(), now, Id, TenantId, PlanCode));
    }
}
