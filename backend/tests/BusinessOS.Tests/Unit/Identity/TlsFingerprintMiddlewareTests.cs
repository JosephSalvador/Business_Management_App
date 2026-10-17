using BusinessOS.Api.Http;
using BusinessOS.Api.Middleware;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class TlsFingerprintMiddlewareTests
{
    private readonly TlsRiskOptions _options = new()
    {
        Enabled = true,
        MinimumBotScoreThreshold = 15,
        BlockedJa3Fingerprints = new List<string> { "b32309a26ce51605669718c9842d3485" }
    };

    [Fact]
    public async Task InvokeAsync_ExtractsHeaders_IntoRequestContext()
    {
        var invoked = false;
        var middleware = new TlsFingerprintMiddleware(
            next: (ctx) => { invoked = true; return Task.CompletedTask; },
            logger: NullLogger<TlsFingerprintMiddleware>.Instance,
            options: Options.Create(_options));

        var context = new DefaultHttpContext();
        context.Request.Path = "/api/v1/catalog/products";
        context.Request.Headers["CF-JA3-Fingerprint"] = "valid-browser-ja3";
        context.Request.Headers["CF-Bot-Score"] = "99";

        var requestContext = new RequestContext();

        await middleware.InvokeAsync(context, requestContext);

        Assert.True(invoked);
        Assert.Equal("valid-browser-ja3", requestContext.TlsFingerprint);
        Assert.Equal(99, requestContext.BotScore);
        Assert.Equal("valid-browser-ja3", context.Items["TlsFingerprint"]);
        Assert.Equal(99, context.Items["BotScore"]);
    }

    [Fact]
    public async Task InvokeAsync_RejectsHighRiskBotScore_OnAuthLogin()
    {
        var invoked = false;
        var middleware = new TlsFingerprintMiddleware(
            next: (ctx) => { invoked = true; return Task.CompletedTask; },
            logger: NullLogger<TlsFingerprintMiddleware>.Instance,
            options: Options.Create(_options));

        var context = new DefaultHttpContext();
        context.Request.Path = "/api/v1/auth/login";
        context.Request.Headers["CF-Bot-Score"] = "5"; // Extremely low score (< 15 threshold)

        var requestContext = new RequestContext();

        await middleware.InvokeAsync(context, requestContext);

        Assert.False(invoked);
        Assert.Equal(StatusCodes.Status403Forbidden, context.Response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_RejectsBlockedJa3_OnAuthRegister()
    {
        var invoked = false;
        var middleware = new TlsFingerprintMiddleware(
            next: (ctx) => { invoked = true; return Task.CompletedTask; },
            logger: NullLogger<TlsFingerprintMiddleware>.Instance,
            options: Options.Create(_options));

        var context = new DefaultHttpContext();
        context.Request.Path = "/api/v1/auth/register";
        context.Request.Headers["CF-JA3-Fingerprint"] = "b32309a26ce51605669718c9842d3485"; // Blocked python-requests

        var requestContext = new RequestContext();

        await middleware.InvokeAsync(context, requestContext);

        Assert.False(invoked);
        Assert.Equal(StatusCodes.Status403Forbidden, context.Response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_AllowsLegitimateRequest_OnAuthRoute()
    {
        var invoked = false;
        var middleware = new TlsFingerprintMiddleware(
            next: (ctx) => { invoked = true; return Task.CompletedTask; },
            logger: NullLogger<TlsFingerprintMiddleware>.Instance,
            options: Options.Create(_options));

        var context = new DefaultHttpContext();
        context.Request.Path = "/api/v1/auth/login";
        context.Request.Headers["CF-Bot-Score"] = "85";
        context.Request.Headers["CF-JA3-Fingerprint"] = "legitimate-chrome-fingerprint";

        var requestContext = new RequestContext();

        await middleware.InvokeAsync(context, requestContext);

        Assert.True(invoked);
        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_AllowsNonAuthRoute_EvenIfBotScoreLow()
    {
        var invoked = false;
        var middleware = new TlsFingerprintMiddleware(
            next: (ctx) => { invoked = true; return Task.CompletedTask; },
            logger: NullLogger<TlsFingerprintMiddleware>.Instance,
            options: Options.Create(_options));

        var context = new DefaultHttpContext();
        context.Request.Path = "/api/v1/public/terms";
        context.Request.Headers["CF-Bot-Score"] = "2";

        var requestContext = new RequestContext();

        await middleware.InvokeAsync(context, requestContext);

        Assert.True(invoked);
        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
    }
}
