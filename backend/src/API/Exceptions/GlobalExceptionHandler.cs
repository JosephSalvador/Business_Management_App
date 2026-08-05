using BusinessOS.Api.Http;
using BusinessOS.Api.Middleware;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Serilog.Context;

namespace BusinessOS.Api.Exceptions;

public sealed class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;
    private readonly IHostEnvironment _environment;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger, IHostEnvironment environment)
    {
        _logger = logger;
        _environment = environment;
    }

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (status, title) = exception switch
        {
            UnauthorizedAccessException => (StatusCodes.Status403Forbidden, "Forbidden"),
            KeyNotFoundException => (StatusCodes.Status404NotFound, "Not Found"),
            BadHttpRequestException => (StatusCodes.Status400BadRequest, "Bad Request"),
            _ => (StatusCodes.Status500InternalServerError, "Internal Server Error"),
        };

        var correlationId = httpContext.Items[CorrelationIdMiddleware.CorrelationIdKey] as string ?? string.Empty;

        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            if (status >= StatusCodes.Status500InternalServerError)
            {
                _logger.LogError(exception, "Unhandled exception processing {Method} {Path}",
                    httpContext.Request.Method, httpContext.Request.Path);
            }
            else
            {
                _logger.LogWarning(exception, "Request {Method} {Path} failed with {Status}",
                    httpContext.Request.Method, httpContext.Request.Path, status);
            }
        }

        var details = new ProblemDetails
        {
            Title = title,
            Status = status,
            Detail = _environment.IsProduction()
                ? "An unexpected error occurred. Please try again later."
                : exception.Message,
            Instance = httpContext.Request.Path,
        };
        details.Extensions["code"] = "Internal";
        details.Extensions["traceId"] = httpContext.TraceIdentifier;
        details.Extensions["correlationId"] = correlationId;

        httpContext.Response.StatusCode = status;
        httpContext.Response.ContentType = "application/problem+json";
        await httpContext.Response.WriteAsJsonAsync(details, cancellationToken);
        return true;
    }
}
