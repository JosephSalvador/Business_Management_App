using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Finance;

public enum CashSessionStatus
{
    Open = 0,
    Closed = 1
}

public sealed class CashSession : AggregateRoot
{
    private CashSession(
        Guid id,
        Guid tenantId,
        Guid accountId,
        decimal openingCash)
        : base(id)
    {
        TenantId = tenantId;
        AccountId = accountId;
        OpeningCash = openingCash;
        Status = CashSessionStatus.Open;
        OpenedAt = DateTime.UtcNow;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid AccountId { get; private set; }
    public decimal OpeningCash { get; private set; }
    public decimal? ClosingCash { get; private set; }
    public decimal? ExpectedCash { get; private set; }
    public decimal? Variance { get; private set; }
    public CashSessionStatus Status { get; private set; }
    public DateTime OpenedAt { get; private set; }
    public DateTime? ClosedAt { get; private set; }
    public string? Notes { get; private set; }

    public static CashSession Open(Guid tenantId, Guid accountId, decimal openingCash)
    {
        if (openingCash < 0)
            throw new ArgumentException("Opening cash cannot be negative.");

        return new CashSession(Guid.NewGuid(), tenantId, accountId, openingCash);
    }

    public void Close(decimal closingCash, decimal expectedCash, string? notes = null)
    {
        if (Status != CashSessionStatus.Open)
            throw new InvalidOperationException("Cash session is already closed.");

        ClosingCash = closingCash;
        ExpectedCash = expectedCash;
        Variance = closingCash - expectedCash;
        Notes = notes?.Trim();
        Status = CashSessionStatus.Closed;
        ClosedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }
}
