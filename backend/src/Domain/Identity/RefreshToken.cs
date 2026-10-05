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
        Guid familyId,
        string? deviceLabel,
        string? ipAddress,
        string? userAgent)
        : base(id)
    {
        UserId = userId;
        TenantId = tenantId;
        TokenHash = tokenHash;
        ExpiresAt = expiresAt;
        FamilyId = familyId;
        DeviceLabel = deviceLabel;
        IpAddress = ipAddress;
        UserAgent = userAgent;
    }

    public Guid UserId { get; private set; }
    public Guid TenantId { get; private set; }
    public string TokenHash { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? RevokedAt { get; private set; }
    public Guid? ReplacedByTokenId { get; private set; }
    public Guid FamilyId { get; private set; }

    /// <summary>Human-readable device name shown on the sessions page.</summary>
    public string? DeviceLabel { get; private set; }

    public string? IpAddress { get; private set; }
    public string? UserAgent { get; private set; }

    /// <summary>Start of the rotation family this token belongs to — the session's login time.</summary>
    public DateTime CreatedAtUtc => CreatedAt;

    public bool IsActive => RevokedAt is null && ExpiresAt > DateTime.UtcNow;

    public static RefreshToken Create(
        Guid userId,
        Guid tenantId,
        string tokenHash,
        DateTime expiresAt,
        string? deviceLabel = null,
        string? ipAddress = null,
        string? userAgent = null)
        => new(
            Guid.NewGuid(), userId, tenantId, tokenHash, expiresAt, Guid.NewGuid(),
            deviceLabel, ipAddress, userAgent);

    public void Revoke(Guid? replacedByTokenId = null)
    {
        RevokedAt = DateTime.UtcNow;
        ReplacedByTokenId = replacedByTokenId;
    }
}
