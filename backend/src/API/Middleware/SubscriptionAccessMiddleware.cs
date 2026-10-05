using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Billing;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;

namespace BusinessOS.Api.Middleware;

/// <summary>
/// Module enforcement. Runs after <see cref="TenantActiveMiddleware"/> for every
/// authenticated, tenant-scoped request.
///
/// While the subscription is in debt the workspace degrades to the backstop modules
/// (POS + inventory): writes into any other module are rejected with 402 so the client can
/// send the owner to the billing page, and reads keep flowing so the shell still renders.
///
/// With a healthy subscription the workspace gets the full backstop plus whatever the plan,
/// add-on packages and tenant feature flags grant.
///
/// The evaluation is cached briefly because it hits the subscription, item, plan, flag and
/// invoice tables.
/// </summary>
public sealed class SubscriptionAccessMiddleware
{
    private readonly RequestDelegate _next;

    public SubscriptionAccessMiddleware(RequestDelegate next) => _next = next;

    private const string DebtDetail =
        "This workspace subscription is in debt. Renew to restore full access; " +
        "POS and inventory keep working.";

    public async Task InvokeAsync(
        HttpContext context,
        RequestContext requestContext,
        ISubscriptionEntitlementService entitlement,
        ICacheService cache)
    {
        if (context.User.Identity?.IsAuthenticated != true ||
            requestContext.TenantId is not { } tenantId)
        {
            await _next(context);
            return;
        }

        var module = ModuleRouteMap.Match(context.Request.Path.Value);
        if (module is null)
        {
            await _next(context);
            return;
        }

        var isRead = HttpMethods.IsGet(context.Request.Method) ||
            HttpMethods.IsHead(context.Request.Method) ||
            HttpMethods.IsOptions(context.Request.Method);
        if (isRead)
        {
            await _next(context);
            return;
        }

        var key = SubscriptionEntitlementCache.Key(tenantId);
        var evaluation = await cache.GetAsync<SubscriptionEntitlement>(key, context.RequestAborted);
        if (evaluation is null)
        {
            evaluation = await entitlement.GetEntitlementAsync(tenantId, context.RequestAborted);
            await cache.SetAsync(
                key,
                evaluation,
                SubscriptionEntitlementCache.Lifetime,
                context.RequestAborted);
        }

        if (evaluation.EffectiveFeatureKeys.Contains(module.FeatureKey, StringComparer.Ordinal))
        {
            await _next(context);
            return;
        }

        if (evaluation.AccessLevel != AccessLevel.Full)
        {
            await WriteProblemAsync(
                context,
                StatusCodes.Status402PaymentRequired,
                "BillingRequired",
                DebtDetail);
            return;
        }

        await WriteProblemAsync(
            context,
            StatusCodes.Status403Forbidden,
            "ModuleDisabled",
            $"The {module.Name} module is not enabled for this workspace.",
            module.Id,
            module.FeatureKey);
    }

    private static async Task WriteProblemAsync(
        HttpContext context,
        int status,
        string code,
        string detail,
        string? module = null,
        string? featureKey = null)
    {
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/problem+json";

        var body = new Dictionary<string, object?>
        {
            ["title"] = code,
            ["status"] = status,
            ["code"] = code,
            ["detail"] = detail,
        };

        if (module is not null)
        {
            body["module"] = module;
        }

        if (featureKey is not null)
        {
            body["featureKey"] = featureKey;
        }

        await context.Response.WriteAsJsonAsync(body, context.RequestAborted);
    }
}
