using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Finance;

public enum MoneyAccountType
{
    Cash = 0,
    MobileMoney = 1,
    Bank = 2,
    Other = 3
}

public sealed class MoneyAccount : AggregateRoot
{
    private MoneyAccount(
        Guid id,
        Guid tenantId,
        string name,
        MoneyAccountType type,
        string? reference)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        Type = type;
        Reference = reference;
        Balance = 0;
        IsActive = true;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public MoneyAccountType Type { get; private set; }
    public string? Reference { get; private set; }
    public decimal Balance { get; private set; }
    public bool IsActive { get; private set; }

    public static MoneyAccount Create(
        Guid tenantId,
        string name,
        MoneyAccountType type,
        string? reference = null)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Account name is required.", nameof(name));

        return new MoneyAccount(Guid.NewGuid(), tenantId, name.Trim(), type, reference?.Trim());
    }

    public void Credit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Credit amount must be positive.");
        Balance += amount;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Debit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Debit amount must be positive.");
        if (Balance < amount)
            throw new InvalidOperationException("Insufficient balance.");
        Balance -= amount;
        UpdatedAt = DateTime.UtcNow;
    }

    public void UpdateDetails(string name, string? reference)
    {
        Name = name.Trim();
        Reference = reference?.Trim();
        UpdatedAt = DateTime.UtcNow;
    }

    public void Deactivate()
    {
        IsActive = false;
        UpdatedAt = DateTime.UtcNow;
    }
}

public enum TransactionType
{
    Credit = 0,
    Debit = 1,
    Transfer = 2
}

public sealed class MoneyAccountTransaction : Entity
{
    private MoneyAccountTransaction(
        Guid id,
        Guid tenantId,
        Guid accountId,
        TransactionType type,
        decimal amount,
        decimal balanceAfter,
        string description,
        Guid? relatedAccountId,
        string? reference)
        : base(id)
    {
        TenantId = tenantId;
        AccountId = accountId;
        Type = type;
        Amount = amount;
        BalanceAfter = balanceAfter;
        Description = description;
        RelatedAccountId = relatedAccountId;
        Reference = reference;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid AccountId { get; private set; }
    public TransactionType Type { get; private set; }
    public decimal Amount { get; private set; }
    public decimal BalanceAfter { get; private set; }
    public string Description { get; private set; }
    public Guid? RelatedAccountId { get; private set; }
    public string? Reference { get; private set; }

    public static MoneyAccountTransaction Create(
        Guid tenantId,
        Guid accountId,
        TransactionType type,
        decimal amount,
        decimal balanceAfter,
        string description,
        Guid? relatedAccountId = null,
        string? reference = null)
    {
        return new MoneyAccountTransaction(
            Guid.NewGuid(), tenantId, accountId, type,
            amount, balanceAfter, description.Trim(),
            relatedAccountId, reference?.Trim());
    }
}
