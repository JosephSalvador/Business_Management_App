using BusinessOS.Application.Ports;
using BusinessOS.Shared;

namespace BusinessOS.Application.Features.Users;

/// <summary>
/// Centralized guard for the "last active system Administrator" invariant. Every operation
/// that can remove an active administrator from the tenant pool (deactivate, soft-delete,
/// demote away from the Administrator role) must go through here. The count is authoritative
/// because it is re-read inside the tenant advisory-lock transaction acquired by the pipeline.
/// </summary>
internal static class UserAdminGuard
{
    internal static async Task<Error?> EnsureAdministratorRemainsAsync(
        IUserRepository users,
        Guid tenantId,
        Guid targetUserId,
        string action,
        CancellationToken cancellationToken)
    {
        var remaining = await users.CountActiveAdministratorsAsync(tenantId, targetUserId, cancellationToken);
        return remaining == 0
            ? Error.Conflict($"You cannot {action} the last active administrator.")
            : null;
    }
}
