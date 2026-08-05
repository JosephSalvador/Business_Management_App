using Microsoft.AspNetCore.Builder;

namespace BusinessOS.Api.Authorization;

public static class RequirePermissionExtensions
{
    public static RouteHandlerBuilder RequirePermission(this RouteHandlerBuilder builder, string permission)
        => builder.RequireAuthorization(policy => policy.RequireClaim("permission", permission));
}
