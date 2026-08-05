using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared.Events;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Workers.Outbox;

/// <summary>
/// Background host that reliably delivers outbox messages whose in-process publish did not
/// complete (e.g. the API crashed between commit and dispatch). Polls every few seconds.
/// Consumers must be idempotent.
/// </summary>
public sealed class OutboxDispatcherService : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(5);
    private const int BatchSize = 100;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OutboxDispatcherService> _logger;

    public OutboxDispatcherService(
        IServiceScopeFactory scopeFactory,
        ILogger<OutboxDispatcherService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Outbox dispatcher started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await DispatchPendingAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Outbox dispatch cycle failed.");
            }

            await Task.Delay(PollInterval, stoppingToken);
        }

        _logger.LogInformation("Outbox dispatcher stopped.");
    }

    private async Task DispatchPendingAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BusinessDbContext>();
        var eventBus = scope.ServiceProvider.GetRequiredService<IEventBus>();

        var messages = await db.OutboxMessages
            .Where(o => o.ProcessedAt == null)
            .OrderBy(o => o.OccurredAt)
            .Take(BatchSize)
            .ToListAsync(cancellationToken);

        if (messages.Count == 0)
        {
            return;
        }

        _logger.LogInformation("Dispatching {Count} outbox message(s).", messages.Count);

        foreach (var message in messages)
        {
            await DispatchOneAsync(db, eventBus, message, cancellationToken);
        }

        await db.SaveChangesAsync(cancellationToken);
    }

    private async Task DispatchOneAsync(
        BusinessDbContext db,
        IEventBus eventBus,
        OutboxMessage message,
        CancellationToken cancellationToken)
    {
        try
        {
            var eventType = ResolveType(message.Type);
            if (eventType is null || !typeof(IDomainEvent).IsAssignableFrom(eventType))
            {
                message.Error = $"Unknown event type: {message.Type}";
                message.ProcessedAt = DateTime.UtcNow;
                return;
            }

            var domainEvent = JsonSerializer.Deserialize(message.Payload, eventType) as IDomainEvent;
            if (domainEvent is null)
            {
                message.Error = $"Could not deserialize event: {message.Type}";
                message.ProcessedAt = DateTime.UtcNow;
                return;
            }

            await eventBus.PublishAsync(domainEvent, cancellationToken);
            message.ProcessedAt = DateTime.UtcNow;
        }
        catch (Exception ex)
        {
            message.Error = ex.Message;
            _logger.LogError(ex, "Outbox message {MessageId} ({Type}) failed.", message.Id, message.Type);
        }
    }

    private static Type? ResolveType(string fullName)
        => AppDomain.CurrentDomain
            .GetAssemblies()
            .Select(a => a.GetType(fullName))
            .FirstOrDefault(t => t is not null);
}
