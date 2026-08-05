using BusinessOS.Api.Http;
using Serilog.Context;

namespace BusinessOS.Api.Middleware;

public sealed class CorrelationIdMiddleware
{
    public const string CorrelationIdKey = "CorrelationId";
    public const string DefaultHeaderName = "X-Correlation-ID";

    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context, RequestContext requestContext)
    {
        var correlationId = context.Request.Headers.TryGetValue(DefaultHeaderName, out var value)
            && Guid.TryParse(value.ToString(), out var parsed)
            ? parsed.ToString("D")
            : Guid.NewGuid().ToString("D");

        context.Items[CorrelationIdKey] = correlationId;
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[DefaultHeaderName] = correlationId;
            return Task.CompletedTask;
        });

        requestContext.CorrelationId = correlationId;
        requestContext.IpAddress = context.Connection.RemoteIpAddress?.ToString();

        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await _next(context);
        }
    }
}
