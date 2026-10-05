using BusinessOS.Infrastructure;
using BusinessOS.Infrastructure.Jobs;
using BusinessOS.Notifications;
using BusinessOS.Shared.Configuration;
using BusinessOS.Workers.Cleanup;
using BusinessOS.Workers.Jobs;
using BusinessOS.Workers.Outbox;

var builder = Host.CreateApplicationBuilder(args);

builder.Services
    .AddInfrastructure(builder.Configuration)
    .AddNotificationEngine()
    .AddJobQueue()
    .AddBackgroundJobs()
    .Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName))
    .AddHostedService<OutboxDispatcherService>()
    .AddHostedService<TokenCleanupService>();

var host = builder.Build();

await host.RunAsync();
