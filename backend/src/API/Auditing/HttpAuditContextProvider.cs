using BusinessOS.Api.Http;
using BusinessOS.Application.Ports;
using BusinessOS.Shared.Audit;
using Microsoft.AspNetCore.Http;

namespace BusinessOS.Api.Auditing;

public sealed class HttpAuditContextProvider : IAuditContextProvider
{
    private readonly RequestContext _requestContext;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public HttpAuditContextProvider(RequestContext requestContext, IHttpContextAccessor httpContextAccessor)
    {
        _requestContext = requestContext;
        _httpContextAccessor = httpContextAccessor;
    }

    public Task<AuditContext> GetContextAsync(CancellationToken ct = default)
    {
        var userAgent = _httpContextAccessor.HttpContext?.Request.Headers["User-Agent"].ToString();

        return Task.FromResult(new AuditContext(
            _requestContext.UserId,
            _requestContext.TenantId,
            _requestContext.IpAddress,
            _requestContext.CorrelationId,
            string.IsNullOrWhiteSpace(userAgent) ? null : userAgent));
    }
}
