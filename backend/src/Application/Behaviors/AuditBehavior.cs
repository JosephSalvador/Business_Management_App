using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Behaviors;

public sealed class AuditBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
    where TResponse : Result, IResult<TResponse>
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private static readonly string[] SensitiveTerms = { "password", "secret", "token", "apikey", "authorization", "key" };

    private readonly IAuditContextProvider _contextProvider;
    private readonly IAuditLogRepository _auditLogs;

    public AuditBehavior(IAuditContextProvider contextProvider, IAuditLogRepository auditLogs)
    {
        _contextProvider = contextProvider;
        _auditLogs = auditLogs;
    }

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var response = await next();

        var requestName = typeof(TRequest).Name;
        // Queries and read operations must never generate mutation audit records
        if (requestName.EndsWith("Query", StringComparison.OrdinalIgnoreCase) ||
            requestName.StartsWith("Get", StringComparison.OrdinalIgnoreCase) ||
            requestName.StartsWith("List", StringComparison.OrdinalIgnoreCase) ||
            requestName.StartsWith("Search", StringComparison.OrdinalIgnoreCase) ||
            requestName.StartsWith("Check", StringComparison.OrdinalIgnoreCase) ||
            !requestName.EndsWith("Command", StringComparison.OrdinalIgnoreCase) ||
            response.IsFailure)
        {
            return response;
        }

        var context = await _contextProvider.GetContextAsync(cancellationToken);
        var changes = JsonSerializer.Serialize(new
        {
            before = Redact(request),
            after = Redact(response),
            correlationId = context.CorrelationId,
            device = context.Device,
        }, JsonOptions);

        var log = AuditLog.Create(
            context.TenantId ?? Guid.Empty,
            context.UserId,
            typeof(TRequest).Name,
            "Command",
            changes: changes,
            ipAddress: context.IpAddress);

        await _auditLogs.AddAsync(log, cancellationToken);

        return response;
    }

    private static JsonNode? Redact(object? value)
    {
        var node = JsonSerializer.SerializeToNode(value, JsonOptions);
        RedactSensitive(node);
        return node;
    }

    private static void RedactSensitive(JsonNode? node)
    {
        if (node is not JsonObject obj)
        {
            return;
        }

        foreach (var property in obj.ToList())
        {
            if (SensitiveTerms.Any(term => property.Key.Contains(term, StringComparison.OrdinalIgnoreCase)))
            {
                obj[property.Key] = "***REDACTED***";
            }
            else
            {
                RedactSensitive(property.Value);
            }
        }
    }
}
