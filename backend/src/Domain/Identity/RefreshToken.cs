using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public sealed class RefreshToken : Entity
{
    private RefreshToken(
        Guid id,
        Guid userId,
        Guid tenantId,
        string tokenHash,
        DateTime expiresAt,
        Guid familyId)
        : base(id)
    {
        UserId = userId;
        TenantId = tenantId;
        TokenHash = tokenHash;
        ExpiresAt = expiresAt;
        FamilyId = familyId;
    }

    public Guid UserId { get; private set; }
    public Guid TenantId { get; private set; }
    public string TokenHash { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? RevokedAt { get; private set; }
    public Guid? ReplacedByTokenId { get; private set; }
    public Guid FamilyId { get; private set; }

    public bool IsActive => RevokedAt is null && ExpiresAt > DateTime.UtcNow;

    public static RefreshToken Create(Guid userId, Guid tenantId, string tokenHash, DateTime expiresAt)
        => new(Guid.NewGuid(), userId, tenantId, tokenHash, expiresAt, Guid.NewGuid());

    public void Revoke(Guid? replacedByTokenId = null)
    {
        RevokedAt = DateTime.UtcNow;
        ReplacedByTokenId = replacedByTokenId;
    }
}
