using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

/// <summary>
/// Single-use recovery code issued alongside an enrolled second factor. Only the SHA-256
/// hash is persisted; the raw code is returned to the client exactly once at generation
/// and cannot be recovered afterwards.
/// </summary>
public sealed class TwoFactorRecoveryCode : Entity
{
    private TwoFactorRecoveryCode(Guid id, Guid tenantId, Guid userId, string codeHash)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        CodeHash = codeHash;
    }

    public Guid TenantId { get; private set; }
    public Guid UserId { get; private set; }
    public string CodeHash { get; private set; }
    public DateTime? UsedAt { get; private set; }

    public bool IsUsed => UsedAt is not null;

    /// <param name="codeHash">Lowercase hex SHA-256 of the raw code.</param>
    public static TwoFactorRecoveryCode Create(Guid tenantId, Guid userId, string codeHash)
        => new(Guid.NewGuid(), tenantId, userId, codeHash);

    /// <summary>Consumes the code. Returns false when it was already used.</summary>
    public bool TryConsume()
    {
        if (IsUsed)
        {
            return false;
        }

        UsedAt = DateTime.UtcNow;
        return true;
    }
}
