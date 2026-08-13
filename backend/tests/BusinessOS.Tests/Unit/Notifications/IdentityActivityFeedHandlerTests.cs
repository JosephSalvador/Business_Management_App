using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Notifications.Events;
using BusinessOS.Tests.Support;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace BusinessOS.Tests.Unit.Notifications;

public sealed class IdentityActivityFeedHandlerTests
{
    private readonly IdentityActivityFeedHandler _handler =
        new(NullLogger<IdentityActivityFeedHandler>.Instance);

    [Fact]
    public async Task UserEvents_AreHandled()
    {
        await _handler.HandleAsync(new UserCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "user@test.local", "User"));
        await _handler.HandleAsync(new UserProfileUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "User", null));
        await _handler.HandleAsync(new UserRolesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), new[] { Guid.NewGuid() }));
        await _handler.HandleAsync(new UserStatusChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), true));
        await _handler.HandleAsync(new UserBranchesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), new[] { Guid.NewGuid() }, null));
    }

    [Fact]
    public async Task RoleEvents_AreHandled()
    {
        await _handler.HandleAsync(new RoleCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "Manager"));
        await _handler.HandleAsync(new RoleUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "Manager"));
        await _handler.HandleAsync(new RolePermissionsChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), new[] { "Users.View" }));
        await _handler.HandleAsync(new RoleDeletedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "Manager"));
    }
}

public sealed class IdentityActivityFeedRegistrationTests : IClassFixture<BusinessOsApiFactory>
{
    private readonly BusinessOsApiFactory _factory;

    public IdentityActivityFeedRegistrationTests(BusinessOsApiFactory factory) => _factory = factory;

    [Fact]
    public void IdentityEvents_AreWiredToActivityFeedHandler()
    {
        using var scope = _factory.Services.CreateScope();
        var services = scope.ServiceProvider;

        foreach (var eventType in new[]
                 {
                     typeof(UserCreatedEvent),
                     typeof(UserProfileUpdatedEvent),
                     typeof(UserRolesChangedEvent),
                     typeof(UserStatusChangedEvent),
                     typeof(UserBranchesChangedEvent),
                     typeof(RoleCreatedEvent),
                     typeof(RoleUpdatedEvent),
                     typeof(RolePermissionsChangedEvent),
                     typeof(RoleDeletedEvent),
                 })
        {
            var handlerType = typeof(IDomainEventHandler<>).MakeGenericType(eventType);
            var handler = services.GetRequiredService(handlerType);
            Assert.IsAssignableFrom<IdentityActivityFeedHandler>(handler);
        }
    }
}
