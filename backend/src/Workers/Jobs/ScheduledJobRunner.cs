using System.Collections.Concurrent;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Workers.Jobs;

/// <summary>
/// Background host that runs recurring jobs on a fixed tick. Jobs register once via
/// <see cref="Register"/> (typically before the host starts) and run in a scoped
/// IServiceProvider so they can resolve IJobQueue and friends.
/// </summary>
public sealed class ScheduledJobRunner : BackgroundService
{
    private static readonly TimeSpan TickInterval = TimeSpan.FromSeconds(60);
    private static readonly ConcurrentDictionary<string, ScheduledJob> Jobs = new();

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ScheduledJobRunner> _logger;

    public ScheduledJobRunner(IServiceScopeFactory scopeFactory, ILogger<ScheduledJobRunner> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public static void Register(string key, TimeSpan interval, Func<IServiceProvider, CancellationToken, Task> work)
        => Jobs[key] = new ScheduledJob(key, interval, work);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Scheduled job runner started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunDueJobsAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Scheduled job cycle failed.");
            }

            await Task.Delay(TickInterval, stoppingToken);
        }

        _logger.LogInformation("Scheduled job runner stopped.");
    }

    private async Task RunDueJobsAsync(CancellationToken stoppingToken)
    {
        var now = DateTime.UtcNow;

        foreach (var job in Jobs.Values)
        {
            if (job.LastRunAt is not null && now - job.LastRunAt.Value < job.Interval)
            {
                continue;
            }

            job.LastRunAt = now;

            try
            {
                using var scope = _scopeFactory.CreateScope();
                await job.Work(scope.ServiceProvider, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Scheduled job {Key} failed.", job.Key);
            }
        }
    }

    private sealed class ScheduledJob
    {
        public ScheduledJob(string key, TimeSpan interval, Func<IServiceProvider, CancellationToken, Task> work)
        {
            Key = key;
            Interval = interval;
            Work = work;
        }

        public string Key { get; }
        public TimeSpan Interval { get; }
        public Func<IServiceProvider, CancellationToken, Task> Work { get; }
        public DateTime? LastRunAt { get; set; }
    }
}
