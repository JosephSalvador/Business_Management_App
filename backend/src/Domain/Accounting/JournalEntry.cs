using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

public sealed class JournalEntry : AggregateRoot
{
    private readonly List<JournalEntryLine> _lines = new();

    private JournalEntry(Guid id, Guid tenantId, string description, DateTime entryDate, string? sourceType, Guid? sourceId) : base(id)
    {
        TenantId = tenantId;
        Description = description.Trim();
        EntryDate = entryDate;
        SourceType = sourceType;
        SourceId = sourceId;
        Status = JournalEntryStatus.Draft;
    }

    public Guid TenantId { get; private set; }
    public string Description { get; private set; } = string.Empty;
    public DateTime EntryDate { get; private set; }
    public string? SourceType { get; private set; }
    public Guid? SourceId { get; private set; }
    public JournalEntryStatus Status { get; private set; }
    public decimal TotalDebit { get; private set; }
    public decimal TotalCredit { get; private set; }
    public DateTime? PostedAt { get; private set; }
    public DateTime? VoidedAt { get; private set; }
    public IReadOnlyCollection<JournalEntryLine> Lines => _lines.AsReadOnly();

    public static JournalEntry Create(
        Guid tenantId,
        string description,
        DateTime entryDate,
        string? sourceType,
        Guid? sourceId,
        IEnumerable<JournalEntryLine> lines)
    {
        var lineList = lines.ToList();
        if (lineList.Count == 0)
            throw new InvalidOperationException("Journal entry must have at least one line.");

        var totalDebit = lineList.Sum(l => l.DebitAmount);
        var totalCredit = lineList.Sum(l => l.CreditAmount);

        if (totalDebit != totalCredit)
            throw new InvalidOperationException($"Debits ({totalDebit}) must equal credits ({totalCredit}).");

        var je = new JournalEntry(Guid.NewGuid(), tenantId, description, entryDate, sourceType, sourceId);

        foreach (var line in lineList)
        {
            line.AttachTo(je.Id);
            je._lines.Add(line);
        }

        je.TotalDebit = totalDebit;
        je.TotalCredit = totalCredit;
        return je;
    }

    public void Post(DateTime postedAt)
    {
        if (Status != JournalEntryStatus.Draft)
            throw new InvalidOperationException($"Cannot post a journal entry in {Status} status.");

        Status = JournalEntryStatus.Posted;
        PostedAt = postedAt;

        AddDomainEvent(new JournalEntryPostedEvent(
            Guid.NewGuid(), postedAt, Id, TenantId,
            Description, TotalDebit, TotalCredit));
    }

    public void Void(DateTime voidedAt)
    {
        if (Status != JournalEntryStatus.Posted)
            throw new InvalidOperationException($"Cannot void a journal entry in {Status} status.");

        Status = JournalEntryStatus.Voided;
        VoidedAt = voidedAt;

        AddDomainEvent(new JournalEntryVoidedEvent(
            Guid.NewGuid(), voidedAt, Id, TenantId,
            Description, TotalDebit, TotalCredit));
    }
}
