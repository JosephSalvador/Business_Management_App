using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Notifications.Events;
using BusinessOS.Tests.Support;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace BusinessOS.Tests.Unit.Notifications;

public sealed class PricingActivityFeedHandlerTests
{
    private readonly PricingActivityFeedHandler _handler =
        new(NullLogger<PricingActivityFeedHandler>.Instance);

    [Fact]
    public async Task PricingEvents_AreHandled()
    {
        await _handler.HandleAsync(new PriceListCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "Default", "TZS", true));
        await _handler.HandleAsync(new PriceListUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "Default", "TZS", true, true));
        await _handler.HandleAsync(new ProductPricesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), 3));
    }
}

public sealed class PricingActivityFeedRegistrationTests : IClassFixture<BusinessOsApiFactory>
{
    private readonly BusinessOsApiFactory _factory;

    public PricingActivityFeedRegistrationTests(BusinessOsApiFactory factory) => _factory = factory;

    [Fact]
    public void PricingEvents_AreWiredToActivityFeedHandler()
    {
        using var scope = _factory.Services.CreateScope();
        var services = scope.ServiceProvider;

        foreach (var eventType in new[]
                 {
                     typeof(PriceListCreatedEvent),
                     typeof(PriceListUpdatedEvent),
                     typeof(ProductPricesChangedEvent),
                 })
        {
            var handlerType = typeof(IDomainEventHandler<>).MakeGenericType(eventType);
            var handler = services.GetRequiredService(handlerType);
            Assert.IsAssignableFrom<PricingActivityFeedHandler>(handler);
        }
    }
}
