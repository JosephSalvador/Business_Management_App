using System.Security.Claims;
using BusinessOS.Api.Http;

namespace BusinessOS.Api.Middleware;

public sealed class UserContextMiddleware
{
    private readonly RequestDelegate _next;

    public UserContextMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context, RequestContext requestContext)
    {
        var nameId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? context.User.FindFirst("sub")?.Value;
        if (Guid.TryParse(nameId, out var userId))
        {
            requestContext.UserId = userId;
        }

        var tenantId = context.User.FindFirst("tenant_id")?.Value;
        if (Guid.TryParse(tenantId, out var tenantGuid))
        {
            requestContext.TenantId = tenantGuid;
        }

        await _next(context);
    }
}
