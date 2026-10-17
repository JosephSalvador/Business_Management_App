using BusinessOS.Api.Http;
using Microsoft.Extensions.Options;

namespace BusinessOS.Api.Middleware;

public sealed class TlsRiskOptions
{
    public const string SectionName = "TlsRisk";

    public bool Enabled { get; set; } = true;
    public int MinimumBotScoreThreshold { get; set; } = 15;
    public List<string> BlockedJa3Fingerprints { get; set; } = new()
    {
        // Known automated credential-stuffing & malicious bot JA3 signatures
        "b32309a26ce51605669718c9842d3485", // Python Requests default TLS fingerprint
        "c12f54a7e991a75c120d8bd6ee812e98", // Mirai / masscan TLS fingerprint
        "137537b03b41d25c3451522f77da8c16", // Old automated exploit scanner
    };
}

/// <summary>
/// Evaluates incoming TLS client fingerprints (JA3/JA4) and bot management scores
/// forwarded by Cloudflare or edge reverse proxies. Gated against sensitive auth routes
/// to stop automated credential stuffing and DDoS before heavy CPU/database operations.
/// </summary>
public sealed class TlsFingerprintMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<TlsFingerprintMiddleware> _logger;
    private readonly TlsRiskOptions _options;
    private readonly HashSet<string> _blockedFingerprints;

    public TlsFingerprintMiddleware(
        RequestDelegate next,
        ILogger<TlsFingerprintMiddleware> logger,
        IOptions<TlsRiskOptions> options)
    {
        _next = next;
        _logger = logger;
        _options = options.Value ?? new TlsRiskOptions();
        _blockedFingerprints = new HashSet<string>(_options.BlockedJa3Fingerprints ?? new(), StringComparer.OrdinalIgnoreCase);
    }

    public async Task InvokeAsync(HttpContext context, RequestContext requestContext)
    {
        // 1. Extract TLS Fingerprint & Bot Score from Edge Headers
        var ja3 = context.Request.Headers["CF-JA3-Fingerprint"].FirstOrDefault()
            ?? context.Request.Headers["X-JA3-Fingerprint"].FirstOrDefault()
            ?? context.Request.Headers["CF-JA4"].FirstOrDefault()
            ?? context.Request.Headers["X-TLS-Client-Fingerprint"].FirstOrDefault();

        var botScoreHeader = context.Request.Headers["CF-Bot-Score"].FirstOrDefault()
            ?? context.Request.Headers["X-Bot-Score"].FirstOrDefault();

        int? botScore = int.TryParse(botScoreHeader, out var parsedScore) ? parsedScore : null;

        if (!string.IsNullOrWhiteSpace(ja3))
        {
            requestContext.TlsFingerprint = ja3;
            context.Items["TlsFingerprint"] = ja3;
        }

        if (botScore.HasValue)
        {
            requestContext.BotScore = botScore.Value;
            context.Items["BotScore"] = botScore.Value;
        }

        // 2. Only gate sensitive auth endpoints to prevent credential stuffing and brute force
        if (_options.Enabled && IsSensitiveAuthRoute(context.Request.Path))
        {
            // Check for explicitly blocked JA3 fingerprints
            if (!string.IsNullOrWhiteSpace(ja3) && _blockedFingerprints.Contains(ja3))
            {
                _logger.LogWarning(
                    "Blocked request to {Path} from IP {RemoteIp}: malicious JA3 fingerprint {Ja3}",
                    context.Request.Path,
                    requestContext.IpAddress ?? context.Connection.RemoteIpAddress?.ToString(),
                    ja3);

                await RejectAsync(context, "Client TLS fingerprint is flagged as high risk.");
                return;
            }

            // Check Cloudflare Bot Management score (score < 15 is high-confidence automated bot)
            if (botScore.HasValue && botScore.Value < _options.MinimumBotScoreThreshold)
            {
                _logger.LogWarning(
                    "Blocked request to {Path} from IP {RemoteIp}: high bot risk score {BotScore} (JA3: {Ja3})",
                    context.Request.Path,
                    requestContext.IpAddress ?? context.Connection.RemoteIpAddress?.ToString(),
                    botScore.Value,
                    ja3 ?? "none");

                await RejectAsync(context, "Automated bot traffic detected and blocked by security policy.");
                return;
            }
        }

        await _next(context);
    }

    private static bool IsSensitiveAuthRoute(PathString path)
    {
        return path.StartsWithSegments("/api/v1/auth/login", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/api/v1/auth/register", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/api/v1/auth/quick-pin-login", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/api/v1/auth/token/refresh", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/api/v1/auth/forgot-password", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task RejectAsync(HttpContext context, string detail)
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        context.Response.ContentType = "application/problem+json; charset=utf-8";
        await context.Response.WriteAsJsonAsync(new
        {
            type = "https://errors.jolinx.com/tls-risk-rejected",
            title = "Forbidden",
            status = StatusCodes.Status403Forbidden,
            detail
        }, context.RequestAborted);
    }
}
