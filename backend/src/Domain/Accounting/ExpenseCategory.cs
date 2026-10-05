using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

/// <summary>
/// Reference data for grouping expenses (Utilities, Transport, Petty Cash…).
/// Name is unique per tenant; categories are never deleted while expenses
/// reference them, so no lifecycle methods exist yet.
/// </summary>
public sealed class ExpenseCategory : AggregateRoot
{
    private ExpenseCategory(Guid id, Guid tenantId, string name)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }

    public static ExpenseCategory Create(Guid tenantId, string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Expense category name is required.", nameof(name));
        }

        if (name.Trim().Length > 50)
        {
            throw new ArgumentException("Expense category name must be at most 50 characters.", nameof(name));
        }

        return new ExpenseCategory(Guid.NewGuid(), tenantId, name.Trim());
    }
}