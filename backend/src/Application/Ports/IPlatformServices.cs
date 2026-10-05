using BusinessOS.Shared.Events;

namespace BusinessOS.Application.Ports;

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

public interface ITokenService
{
    string GenerateAccessToken(Guid userId, Guid tenantId, string email, IReadOnlyCollection<string> permissions);
    string GenerateRefreshToken();
    string HashRefreshToken(string token);
}

/// <summary>
/// RFC 6238 time-based one-time passwords. The secret is base32 text as produced by
/// <see cref="GenerateSecret"/>; verification tolerates a symmetric window of steps to
/// absorb device clock drift.
/// </summary>
public interface ITotpService
{
    string GenerateSecret();
    string GetProvisioningUri(string secret, string accountLabel, string issuer);
    bool VerifyCode(string secret, string code, DateTimeOffset now, int stepSeconds, int digits, int window);
}

/// <summary>
/// Symmetric encryption for short-lived platform secrets (second-factor shared secrets).
/// Distinct from <see cref="IPasswordHasher"/>, which is deliberately one-way.
/// </summary>
public interface ISecretProtector
{
    string Protect(string plaintext);
    string Unprotect(string protectedValue);
}

public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default);
    Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken cancellationToken = default);
    Task RemoveAsync(string key, CancellationToken cancellationToken = default);
}

public interface IEventBus
{
    Task PublishAsync(IDomainEvent domainEvent, CancellationToken cancellationToken = default);
}

public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent domainEvent, CancellationToken cancellationToken = default);
}

public interface ITenantContext
{
    Guid TenantId { get; }
    Guid? UserId { get; }
    string? IpAddress { get; }

    /// <summary>
    /// Raw client user-agent. Present so login can label a session for the device list;
    /// never logged or returned verbatim.
    /// </summary>
    string? UserAgent { get; }

    /// <summary>
    /// The refresh token the current request was authenticated with, when the caller
    /// presented one. Used only to mark "this device" in the session list — never for
    /// authorisation.
    /// </summary>
    string? CurrentRefreshToken { get; }
}
