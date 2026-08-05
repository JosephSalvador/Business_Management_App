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
}
