using BusinessOS.Application.Ports;
using BusinessOS.Shared.Events;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Infrastructure.Events;

/// <summary>
/// In-process event bus: publishes to every registered IDomainEventHandler for the event
/// type. Used for the fast path after a transaction; the outbox worker covers failures.
/// </summary>
public sealed class InProcessEventBus : IEventBus
{
    private readonly IServiceProvider _serviceProvider;

    public InProcessEventBus(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public async Task PublishAsync(IDomainEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var handlerType = typeof(IDomainEventHandler<>).MakeGenericType(domainEvent.GetType());
        var handlers = _serviceProvider.GetServices(handlerType).Cast<object>();

        foreach (var handler in handlers)
        {
            await InvokeHandleAsync(handler, handlerType, domainEvent, cancellationToken);
        }
    }

    private static async Task InvokeHandleAsync(
        object handler,
        Type handlerType,
        IDomainEvent domainEvent,
        CancellationToken cancellationToken)
    {
        var method = handlerType.GetMethod(nameof(IDomainEventHandler<IDomainEvent>.HandleAsync))!;
        var task = (Task)method.Invoke(handler, new object[] { domainEvent, cancellationToken })!;
        await task;
    }
}
