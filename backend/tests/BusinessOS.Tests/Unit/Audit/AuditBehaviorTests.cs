using BusinessOS.Application.Behaviors;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using BusinessOS.Shared.Audit;
using MediatR;

namespace BusinessOS.Tests.Unit.Audit;

public sealed class AuditBehaviorTests
{
    private sealed record UpdateProductCommand(int Quantity);

    private sealed record GetSomethingQuery(int Quantity);

    private sealed class StubAuditContextProvider : IAuditContextProvider
    {
        public AuditContext Context { get; set; } = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "10.0.0.1",
            "corr-1",
            "test-agent");

        public Task<AuditContext> GetContextAsync(CancellationToken ct = default) => Task.FromResult(Context);
    }

    private sealed class RecordingAuditLogRepository : IAuditLogRepository
    {
        public List<AuditLog> Added { get; } = new();

        public Task AddAsync(AuditLog auditLog, CancellationToken ct = default)
        {
            Added.Add(auditLog);
            return Task.CompletedTask;
        }
    }

    private static async Task<TResponse> RunAsync<TRequest, TResponse>(
        AuditBehavior<TRequest, TResponse> behavior,
        TRequest request,
        RequestHandlerDelegate<TResponse> next)
        where TRequest : notnull
        where TResponse : Result, IResult<TResponse>
        => await behavior.Handle(request, next, CancellationToken.None);

    [Fact]
    public async Task SuccessfulCommand_RecordsOneAuditLogWithActionAndContext()
    {
        var provider = new StubAuditContextProvider();
        var repository = new RecordingAuditLogRepository();
        var behavior = new AuditBehavior<UpdateProductCommand, Result>(provider, repository);

        var response = await RunAsync(
            behavior,
            new UpdateProductCommand(5),
            _ => Task.FromResult(Result.Success()));

        Assert.True(response.IsSuccess);
        var log = Assert.Single(repository.Added);
        Assert.Equal(nameof(UpdateProductCommand), log.Action);
        Assert.Equal(provider.Context.TenantId!.Value, log.TenantId);
        Assert.Equal(provider.Context.UserId, log.UserId);
        Assert.Equal("Command", log.EntityType);
        Assert.Equal(provider.Context.IpAddress, log.IpAddress);
        Assert.Contains(provider.Context.CorrelationId, log.Changes);
        Assert.Contains(provider.Context.Device!, log.Changes);
        Assert.Contains("before", log.Changes);
        Assert.Contains("after", log.Changes);
    }

    [Fact]
    public async Task FailedCommand_RecordsNothing()
    {
        var provider = new StubAuditContextProvider();
        var repository = new RecordingAuditLogRepository();
        var behavior = new AuditBehavior<UpdateProductCommand, Result>(provider, repository);

        var response = await RunAsync(
            behavior,
            new UpdateProductCommand(5),
            _ => Task.FromResult(Result.Failure(Error.Validation("Invalid."))));

        Assert.True(response.IsFailure);
        Assert.Empty(repository.Added);
    }

    [Fact]
    public async Task QueryType_RecordsNothing()
    {
        var provider = new StubAuditContextProvider();
        var repository = new RecordingAuditLogRepository();
        var behavior = new AuditBehavior<GetSomethingQuery, Result>(provider, repository);

        await RunAsync(
            behavior,
            new GetSomethingQuery(5),
            _ => Task.FromResult(Result.Success()));

        Assert.Empty(repository.Added);
    }
}
