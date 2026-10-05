using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Crm;

public enum CreditTransactionType
{
    Sale = 0,
    Payment = 1,
    Adjustment = 2
}

public sealed class CustomerCredit : AggregateRoot
{
    private CustomerCredit(
        Guid id,
        Guid tenantId,
        Guid customerId)
        : base(id)
    {
        TenantId = tenantId;
        CustomerId = customerId;
        Balance = 0;
        CreditLimit = 0;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid CustomerId { get; private set; }
    public decimal Balance { get; private set; }
    public decimal CreditLimit { get; private set; }
    public DateTime? LastPaymentAt { get; private set; }

    public static CustomerCredit Create(Guid tenantId, Guid customerId)
        => new(Guid.NewGuid(), tenantId, customerId);

    public void SetCreditLimit(decimal limit)
    {
        if (limit < 0) throw new ArgumentException("Credit limit cannot be negative.");
        CreditLimit = limit;
        UpdatedAt = DateTime.UtcNow;
    }

    public void RecordSale(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Sale amount must be positive.");
        Balance += amount;
        UpdatedAt = DateTime.UtcNow;
    }

    public void RecordPayment(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Payment amount must be positive.");
        Balance -= amount;
        LastPaymentAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Adjust(decimal delta)
    {
        Balance += delta;
        UpdatedAt = DateTime.UtcNow;
    }
}

public sealed class CreditTransaction : Entity
{
    private CreditTransaction(
        Guid id,
        Guid tenantId,
        Guid customerId,
        CreditTransactionType type,
        decimal amount,
        decimal balanceAfter,
        string description,
        Guid? relatedSaleId)
        : base(id)
    {
        TenantId = tenantId;
        CustomerId = customerId;
        Type = type;
        Amount = amount;
        BalanceAfter = balanceAfter;
        Description = description;
        RelatedSaleId = relatedSaleId;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid CustomerId { get; private set; }
    public CreditTransactionType Type { get; private set; }
    public decimal Amount { get; private set; }
    public decimal BalanceAfter { get; private set; }
    public string Description { get; private set; }
    public Guid? RelatedSaleId { get; private set; }

    public static CreditTransaction Create(
        Guid tenantId,
        Guid customerId,
        CreditTransactionType type,
        decimal amount,
        decimal balanceAfter,
        string description,
        Guid? relatedSaleId = null)
    {
        return new CreditTransaction(
            Guid.NewGuid(), tenantId, customerId, type,
            amount, balanceAfter, description.Trim(), relatedSaleId);
    }
}
