using BusinessOS.Domain.Identity;
using Microsoft.AspNetCore.Builder;

namespace BusinessOS.Api.Authorization;

public static class RequirePermissionExtensions
{
    public static RouteHandlerBuilder RequirePermission(this RouteHandlerBuilder builder, string permission)
        => builder.RequireAuthorization(policy => policy.RequireAssertion(ctx =>
            ctx.User.HasClaim("platform_role", nameof(PlatformRoleType.PlatformSuperAdmin)) ||
            ctx.User.HasClaim("platform_role", nameof(PlatformRoleType.PlatformStaff)) ||
            ctx.User.HasClaim("permission", permission)));
}
