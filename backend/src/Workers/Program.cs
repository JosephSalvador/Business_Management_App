using BusinessOS.Infrastructure;
using BusinessOS.Notifications;
using BusinessOS.Workers.Cleanup;
using BusinessOS.Workers.Outbox;

var builder = Host.CreateApplicationBuilder(args);

builder.Services
    .AddInfrastructure(builder.Configuration)
    .AddNotifications(builder.Configuration)
    .AddHostedService<OutboxDispatcherService>()
    .AddHostedService<TokenCleanupService>();

var host = builder.Build();

await host.RunAsync();
