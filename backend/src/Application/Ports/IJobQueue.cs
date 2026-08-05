using BusinessOS.Shared.Events;

namespace BusinessOS.Application.Ports;

public interface IJobQueue
{
    Task EnqueueAsync(IDomainEvent job, CancellationToken cancellationToken = default);
}
