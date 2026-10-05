using System.Security.Claims;
using BusinessOS.Application.Ports;
using Microsoft.AspNetCore.Http;

namespace BusinessOS.Infrastructure.Security;

/// <summary>
/// Resolves the current tenant/user from the HttpContext JWT claims. Endpoints that are
/// anonymous (login/register) get TenantId = Guid.Empty and a null user.
/// </summary>
public sealed class HttpTenantContext : ITenantContext
{
    private readonly IHttpContextAccessor _accessor;

    public HttpTenantContext(IHttpContextAccessor accessor) => _accessor = accessor;

    public Guid TenantId
    {
        get
        {
            var value = _accessor.HttpContext?.User.FindFirstValue("tenant_id");
            return Guid.TryParse(value, out var id) ? id : Guid.Empty;
        }
    }

    public Guid? UserId
    {
        get
        {
            var value = _accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(value, out var id) ? id : null;
        }
    }

    public string? IpAddress => _accessor.HttpContext?.Connection.RemoteIpAddress?.ToString();

    public string? UserAgent
    {
        get
        {
            var value = _accessor.HttpContext?.Request.Headers.UserAgent.ToString();
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }
    }

    /// <summary>
    /// Clients present their refresh token in <c>X-Refresh-Token</c> on authenticated calls
    /// so the session list can highlight the current device. Absent on most requests, which
    /// simply means "cannot tell" — never an authorisation input.
    /// </summary>
    public string? CurrentRefreshToken
    {
        get
        {
            var value = _accessor.HttpContext?.Request.Headers["X-Refresh-Token"].ToString();
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }
    }
}
