using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure.Locking;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class InvoiceNumberSequenceServiceTests
{
    private sealed class FakeAdvisoryLock : ITenantAdvisoryLock
    {
        public Task AcquireAsync(Guid tenantId, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class FakeNumberSequenceRepository : INumberSequenceRepository
    {
        private int _invoiceCounter = 0;
        private int _deliveryCounter = 0;

        public Task<string> AllocateAsync(Guid tenantId, string scope, DateTime date, CancellationToken cancellationToken = default)
        {
            if (scope == "DeliveryNote")
            {
                var count = Interlocked.Increment(ref _deliveryCounter);
                return Task.FromResult($"DN-{date:yyyyMMdd}-{count:D4}");
            }

            var invCount = Interlocked.Increment(ref _invoiceCounter);
            return Task.FromResult($"INV-{date:yyyyMMdd}-{invCount:D4}");
        }

        public Task<long> CurrentSequenceAsync(Guid tenantId, string scope, CancellationToken cancellationToken = default)
            => Task.FromResult((long)_invoiceCounter);
    }

    [Fact]
    public async Task NextAsync_WithEmptyTenantId_ThrowsArgumentException()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql("Host=localhost;Database=test;Username=postgres;Password=postgres")
            .Options;
        using var db = new BusinessDbContext(options);
        var service = new InvoiceNumberSequenceService(db, new FakeAdvisoryLock(), new FakeNumberSequenceRepository());

        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.NextAsync(Guid.Empty, DocumentKind.CustomerInvoice, DateTime.UtcNow));
    }

    [Fact]
    public async Task NextAsync_WithoutActiveTransaction_ThrowsInvalidOperationException()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql("Host=localhost;Database=test;Username=postgres;Password=postgres")
            .Options;
        using var db = new BusinessDbContext(options);
        var service = new InvoiceNumberSequenceService(db, new FakeAdvisoryLock(), new FakeNumberSequenceRepository());

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.NextAsync(Guid.NewGuid(), DocumentKind.CustomerInvoice, DateTime.UtcNow));

        Assert.Contains("inside a database transaction", ex.Message);
    }
}
