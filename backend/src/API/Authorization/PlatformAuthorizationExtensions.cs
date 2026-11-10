using BusinessOS.Domain.Identity;
using Microsoft.AspNetCore.Builder;

namespace BusinessOS.Api.Authorization;

public static class PlatformAuthorizationExtensions
{
    public static RouteHandlerBuilder RequirePlatformSuperAdmin(this RouteHandlerBuilder builder)
        => builder.RequireAuthorization(policy => policy.RequireClaim("platform_role", nameof(PlatformRoleType.PlatformSuperAdmin)));

    public static RouteHandlerBuilder RequirePlatformStaffOrSuperAdmin(this RouteHandlerBuilder builder)
        => builder.RequireAuthorization(policy => policy.RequireClaim("platform_role",
            nameof(PlatformRoleType.PlatformStaff),
            nameof(PlatformRoleType.PlatformSuperAdmin)));
}
