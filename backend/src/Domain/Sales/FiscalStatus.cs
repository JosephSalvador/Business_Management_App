namespace BusinessOS.Domain.Sales;

/// <summary>
/// Fiscalization state of a completed sale, written only by the tenant's fiscal adapter
/// (async outbox consumer). A standard tenant never leaves <see cref="NotApplicable"/> — the
/// core sale path never calls a revenue authority.
/// </summary>
public enum FiscalStatus
{
    NotApplicable = 0,
    Pending = 1,
    Submitted = 2,
    Accepted = 3,
    Rejected = 4,
}
