using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

/// <summary>
/// One-time staff invitation code. The owner issues a code for their tenant; a
/// staff member redeems it at registration and is attached to that tenant with
/// the Staff role. Only the SHA-256 hash of the code is stored; the raw code is
/// shown to the owner exactly once. Codes expire after a TTL, are consumed on
/// first successful redemption, and are locked after too many wrong attempts.
/// </summary>
public sealed class InvitationCode : Entity
{
    private InvitationCode(
        Guid id,
        Guid tenantId,
        string codeHash,
        DateTime expiresAt)
        : base(id)
    {
        TenantId = tenantId;
        CodeHash = codeHash;
        ExpiresAt = expiresAt;
    }

    public Guid TenantId { get; private set; }
    public string CodeHash { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? ConsumedAt { get; private set; }
    public int AttemptCount { get; private set; }

    public bool IsUsable => ConsumedAt is null && ExpiresAt > DateTime.UtcNow;

    /// <param name="codeHash">Lowercase hex SHA-256 of the raw code.</param>
    public static InvitationCode Create(Guid tenantId, string codeHash, DateTime expiresAt)
        => new(Guid.NewGuid(), tenantId, codeHash, expiresAt);

    /// <summary>Consumes the code. Returns false when it was already used or expired.</summary>
    public bool TryConsume()
    {
        if (!IsUsable)
        {
            return false;
        }

        ConsumedAt = DateTime.UtcNow;
        return true;
    }

    /// <summary>
    /// Records a failed attempt and locks the code once <paramref name="maxAttempts"/> is
    /// reached, so a leaked code cannot be brute-forced through the API.
    /// </summary>
    public void RegisterFailedAttempt(int maxAttempts)
    {
        AttemptCount++;
        if (AttemptCount >= maxAttempts)
        {
            ConsumedAt = DateTime.UtcNow;
        }
    }
}
