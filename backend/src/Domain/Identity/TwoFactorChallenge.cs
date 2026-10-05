using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

/// <summary>
/// A pending second-factor step, created after the password check passes and consumed when
/// the second factor is proven. Only the SHA-256 hash of the token is persisted, so a dump
/// of this table cannot be replayed as a completed sign-in.
///
/// Modelled as a persisted entity rather than a self-expiring signed blob because the token
/// must be genuinely single-use: a stateless HMAC payload stays valid for its whole TTL and
/// can be replayed to mint an unbounded number of token families. Persistence matches the
/// existing email-verification and password-reset code pattern.
/// </summary>
public sealed class TwoFactorChallenge : Entity
{
    private TwoFactorChallenge(
        Guid id,
        Guid tenantId,
        Guid userId,
        string tokenHash,
        DateTime expiresAt)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        TokenHash = tokenHash;
        ExpiresAt = expiresAt;
    }

    public Guid TenantId { get; private set; }
    public Guid UserId { get; private set; }
    public string TokenHash { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? ConsumedAt { get; private set; }
    public int AttemptCount { get; private set; }

    public bool IsUsable => ConsumedAt is null && ExpiresAt > DateTime.UtcNow;

    /// <param name="tokenHash">Lowercase hex SHA-256 of the raw token.</param>
    public static TwoFactorChallenge Create(Guid tenantId, Guid userId, string tokenHash, DateTime expiresAt)
        => new(Guid.NewGuid(), tenantId, userId, tokenHash, expiresAt);

    /// <summary>
    /// Consumes the challenge. Returns false when it was already used or expired, which is
    /// what makes a replayed token a no-op instead of a second sign-in.
    /// </summary>
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
    /// Records a failed second factor. Bounded per challenge so an attacker who steals a
    /// challenge token cannot iterate 10^6 codes within the challenge's lifetime.
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
