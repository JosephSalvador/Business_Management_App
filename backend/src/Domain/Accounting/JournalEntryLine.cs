using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

public sealed class JournalEntryLine : Entity
{
    private JournalEntryLine(Guid id, Guid accountId, decimal debitAmount, decimal creditAmount, string? description) : base(id)
    {
        AccountId = accountId;
        DebitAmount = debitAmount;
        CreditAmount = creditAmount;
        Description = description;
    }

    public Guid JournalEntryId { get; private set; }
    public Guid AccountId { get; private set; }
    public decimal DebitAmount { get; private set; }
    public decimal CreditAmount { get; private set; }
    public string? Description { get; private set; }

    public static JournalEntryLine Create(Guid accountId, decimal debitAmount, decimal creditAmount, string? description)
    {
        if (debitAmount < 0 || creditAmount < 0)
            throw new InvalidOperationException("Debit and credit amounts must be non-negative.");
        if (debitAmount > 0 && creditAmount > 0)
            throw new InvalidOperationException("A line cannot have both debit and credit amounts.");
        if (debitAmount == 0 && creditAmount == 0)
            throw new InvalidOperationException("A line must have either a debit or credit amount.");

        return new JournalEntryLine(Guid.NewGuid(), accountId, debitAmount, creditAmount, description);
    }

    public void AttachTo(Guid journalEntryId)
    {
        JournalEntryId = journalEntryId;
    }
}
