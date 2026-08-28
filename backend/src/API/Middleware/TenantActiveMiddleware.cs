using System.Security.Claims;
using BusinessOS.Api.Http;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace BusinessOS.Api.Middleware;

/// <summary>
/// Enforces tenant status on every authenticated request (M5.11): a suspended
/// tenant can never use the API — including offline terminals replaying
/// queued sales. The check is cached briefly so normal traffic does not hit
/// the database twice per request.
/// </summary>
public sealed class TenantActiveMiddleware
{
    private readonly RequestDelegate _next;

    public TenantActiveMiddleware(RequestDelegate next) => _next = next;

    private const string SuspendedDetail =
        "This business account is not active. Contact support.";

    public async Task InvokeAsync(
        HttpContext context,
        RequestContext requestContext,
        BusinessDbContext dbContext,
        IMemoryCache cache)
    {
        // Only authenticated, tenant-scoped requests are gated; anonymous
        // endpoints (health, login, register) pass through untouched.
        if (context.User.Identity?.IsAuthenticated != true ||
            requestContext.TenantId is not { } tenantId)
        {
            await _next(context);
            return;
        }

        var isActive = await cache.GetOrCreateAsync($"tenant-active:{tenantId}", entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(30);
            return dbContext.Tenants
                .Where(t => t.Id == tenantId)
                .Select(t => (bool?)t.IsActive)
                .FirstOrDefaultAsync(context.RequestAborted);
        });

        if (isActive != true)
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new
            {
                title = "Tenant Suspended",
                status = StatusCodes.Status403Forbidden,
                detail = SuspendedDetail,
            }, context.RequestAborted);
            return;
        }

        await _next(context);
    }
}
