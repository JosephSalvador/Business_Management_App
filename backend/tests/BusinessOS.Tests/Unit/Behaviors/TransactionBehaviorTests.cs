using BusinessOS.Application.Behaviors;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using BusinessOS.Shared.Events;
using MediatR;

namespace BusinessOS.Tests.Unit.Behaviors;

public sealed class TransactionBehaviorTests
{
    private sealed record TestCommand(int Value) : IRequest<Result>;

    private sealed class StubUnitOfWork : IUnitOfWork
    {
        public int SaveChangesCalls { get; private set; }
        public int BeginTransactionCalls { get; private set; }
        public int CommitTransactionCalls { get; private set; }
        public int RollbackTransactionCalls { get; private set; }

        public Task<IReadOnlyList<DispatchedEvent>> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            SaveChangesCalls++;
            return Task.FromResult<IReadOnlyList<DispatchedEvent>>(Array.Empty<DispatchedEvent>());
        }

        public Task MarkProcessedAsync(IReadOnlyCollection<Guid> outboxMessageIds, CancellationToken cancellationToken = default)
            => Task.CompletedTask;

        public Task BeginTransactionAsync(CancellationToken cancellationToken = default)
        {
            BeginTransactionCalls++;
            return Task.CompletedTask;
        }

        public Task CommitTransactionAsync(CancellationToken cancellationToken = default)
        {
            CommitTransactionCalls++;
            return Task.CompletedTask;
        }

        public Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
        {
            RollbackTransactionCalls++;
            return Task.CompletedTask;
        }
    }

    private sealed class StubEventBus : IEventBus
    {
        public Task PublishAsync(IDomainEvent domainEvent, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class StubAdvisoryLock : ITenantAdvisoryLock
    {
        public Task AcquireAsync(Guid tenantId, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; set; } = Guid.NewGuid();
    }

    [Fact]
    public async Task FailedCommand_DoesNotCallSaveChangesAsync()
    {
        var uow = new StubUnitOfWork();
        var bus = new StubEventBus();
        var lockService = new StubAdvisoryLock();
        var tenantContext = new StubTenantContext();

        var behavior = new TransactionBehavior<TestCommand, Result>(uow, bus, lockService, tenantContext);

        var result = await behavior.Handle(
            new TestCommand(42),
            () => Task.FromResult(Result.Failure(Error.Unauthorized("Bad credentials."))),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(0, uow.SaveChangesCalls);
    }

    [Fact]
    public async Task SuccessfulCommand_CallsSaveChangesAsync()
    {
        var uow = new StubUnitOfWork();
        var bus = new StubEventBus();
        var lockService = new StubAdvisoryLock();
        var tenantContext = new StubTenantContext();

        var behavior = new TransactionBehavior<TestCommand, Result>(uow, bus, lockService, tenantContext);

        var result = await behavior.Handle(
            new TestCommand(42),
            () => Task.FromResult(Result.Success()),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, uow.SaveChangesCalls);
    }
}
