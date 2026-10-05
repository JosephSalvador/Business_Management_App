using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

public sealed class Expense : AggregateRoot
{
    private Expense(
        Guid id,
        Guid tenantId,
        Guid? categoryId,
        string description,
        decimal amount,
        DateTime expenseDate,
        string? paymentMethod,
        string? reference,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        CategoryId = categoryId;
        Description = description;
        Amount = amount;
        ExpenseDate = expenseDate;
        PaymentMethod = paymentMethod;
        Reference = reference;
        Notes = notes;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid? CategoryId { get; private set; }
    public string Description { get; private set; }
    public decimal Amount { get; private set; }
    public DateTime ExpenseDate { get; private set; }
    public string? PaymentMethod { get; private set; }
    public string? Reference { get; private set; }
    public string? Notes { get; private set; }

    public static Expense Create(
        Guid tenantId,
        string description,
        decimal amount,
        DateTime expenseDate,
        Guid? categoryId = null,
        string? paymentMethod = null,
        string? reference = null,
        string? notes = null)
    {
        if (string.IsNullOrWhiteSpace(description))
        {
            throw new ArgumentException("Expense description is required.", nameof(description));
        }

        if (amount <= 0)
        {
            throw new ArgumentException("Expense amount must be greater than zero.", nameof(amount));
        }

        return new Expense(
            Guid.NewGuid(),
            tenantId,
            categoryId,
            description.Trim(),
            amount,
            expenseDate,
            paymentMethod?.Trim(),
            reference?.Trim(),
            notes?.Trim());
    }

    public void UpdateDetails(
        string description,
        decimal amount,
        DateTime expenseDate,
        Guid? categoryId = null,
        string? paymentMethod = null,
        string? reference = null,
        string? notes = null)
    {
        Description = description.Trim();
        Amount = amount;
        ExpenseDate = expenseDate;
        CategoryId = categoryId;
        PaymentMethod = paymentMethod?.Trim();
        Reference = reference?.Trim();
        Notes = notes?.Trim();
        UpdatedAt = DateTime.UtcNow;
    }
}
