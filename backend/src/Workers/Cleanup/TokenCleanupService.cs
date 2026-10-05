using BusinessOS.Application.Ports;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Workers.Cleanup;

/// <summary>
/// Periodically removes revoked and expired refresh tokens to keep the table bounded, and
/// clears spent second-factor challenges. Challenges are kept briefly after expiry so a
/// late-arriving request gets an honest "expired" rather than "unknown", then deleted so the
/// table cannot grow without bound.
/// </summary>
public sealed class TokenCleanupService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(1);
    private static readonly TimeSpan RetiredAfter = TimeSpan.FromDays(30);
    private static readonly TimeSpan ChallengeRetention = TimeSpan.FromHours(1);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TokenCleanupService> _logger;

    public TokenCleanupService(
        IServiceScopeFactory scopeFactory,
        ILogger<TokenCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var deletedChallenges = 0;

                using (var scope = _scopeFactory.CreateScope())
                {
                    var repository = scope.ServiceProvider.GetRequiredService<IRefreshTokenRepository>();
                    var deleted = await repository.DeleteExpiredAsync(
                        DateTime.UtcNow.Subtract(RetiredAfter), stoppingToken);
                    if (deleted > 0)
                    {
                        _logger.LogInformation("Token cleanup removed {Count} stale refresh token(s).", deleted);
                    }

                    var challenges = scope.ServiceProvider.GetRequiredService<ITwoFactorChallengeRepository>();
                    deletedChallenges = await challenges.DeleteExpiredAsync(
                        DateTime.UtcNow.Subtract(ChallengeRetention), stoppingToken);
                }

                if (deletedChallenges > 0)
                {
                    _logger.LogInformation(
                        "Token cleanup removed {Count} spent two-factor challenge(s).", deletedChallenges);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Token cleanup cycle failed.");
            }

            await Task.Delay(Interval, stoppingToken);
        }
    }
}
