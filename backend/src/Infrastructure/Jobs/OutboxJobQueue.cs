using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared.Events;

namespace BusinessOS.Infrastructure.Jobs;

public sealed class OutboxJobQueue : IJobQueue
{
    private readonly BusinessDbContext _db;

    public OutboxJobQueue(BusinessDbContext db) => _db = db;

    public async Task EnqueueAsync(IDomainEvent job, CancellationToken cancellationToken = default)
    {
        var message = new OutboxMessage
        {
            Id = Guid.NewGuid(),
            Type = job.GetType().FullName ?? job.GetType().Name,
            Payload = JsonSerializer.Serialize(job, job.GetType()),
            OccurredAt = job.OccurredAt,
        };

        _db.OutboxMessages.Add(message);
        await _db.SaveChangesAsync(cancellationToken);
    }
}
