using System.Collections.Concurrent;
using BusinessOS.Application.Ports;

namespace BusinessOS.Infrastructure.Authorization;

public sealed class PermissionCacheService : IPermissionService
{
    private static readonly TimeSpan CacheLifetime = TimeSpan.FromMinutes(5);

    private readonly ConcurrentDictionary<(Guid UserId, Guid TenantId), CachedPermissions> _cache = new();
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;
    private readonly TimeProvider _time;

    public PermissionCacheService(IUserRepository users, IRoleRepository roles, TimeProvider? time = null)
    {
        _users = users;
        _roles = roles;
        _time = time ?? TimeProvider.System;
    }

    public async Task<IReadOnlyCollection<string>> GetPermissionsAsync(
        Guid userId,
        Guid tenantId,
        CancellationToken ct = default)
    {
        var key = (userId, tenantId);

        if (_cache.TryGetValue(key, out var cached) && IsFresh(cached))
        {
            return cached.Permissions;
        }

        var permissions = await LoadPermissionsAsync(userId, tenantId, ct);
        _cache[key] = new CachedPermissions(permissions, _time.GetUtcNow());
        return permissions;
    }

    public Task InvalidateAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
    {
        _cache.TryRemove((userId, tenantId), out _);
        return Task.CompletedTask;
    }

    private bool IsFresh(CachedPermissions cached)
        => _time.GetUtcNow() - cached.LoadedAt < CacheLifetime;

    private async Task<IReadOnlyCollection<string>> LoadPermissionsAsync(
        Guid userId, Guid tenantId, CancellationToken ct)
    {
        var user = await _users.GetByIdWithRolesAsync(tenantId, userId, ct);
        if (user is null)
        {
            return Array.Empty<string>();
        }

        var permissions = new HashSet<string>(StringComparer.Ordinal);
        foreach (var role in user.Roles)
        {
            permissions.UnionWith(await _roles.GetPermissionsAsync(tenantId, role.Id, ct));
        }

        return permissions.ToArray();
    }

    private sealed record CachedPermissions(IReadOnlyCollection<string> Permissions, DateTimeOffset LoadedAt);
}
