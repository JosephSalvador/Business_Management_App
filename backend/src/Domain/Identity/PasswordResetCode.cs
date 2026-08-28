using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

/// <summary>
/// Single-use password reset code. Only the SHA-256 hash of the code is stored; the
/// raw code exists solely inside the reset email. A code expires after a configured
/// TTL, is consumed on first successful use, and is locked after too many wrong attempts.
/// </summary>
public sealed class PasswordResetCode : Entity
{
    private PasswordResetCode(
        Guid id,
        Guid tenantId,
        Guid userId,
        string codeHash,
        DateTime expiresAt)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        CodeHash = codeHash;
        ExpiresAt = expiresAt;
    }

    public Guid TenantId { get; private set; }
    public Guid UserId { get; private set; }
    public string CodeHash { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? ConsumedAt { get; private set; }
    public int AttemptCount { get; private set; }

    public bool IsUsable => ConsumedAt is null && ExpiresAt > DateTime.UtcNow;

    /// <param name="codeHash">Lowercase hex SHA-256 of the raw code.</param>
    public static PasswordResetCode Create(Guid tenantId, Guid userId, string codeHash, DateTime expiresAt)
        => new(Guid.NewGuid(), tenantId, userId, codeHash, expiresAt);

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
