using BusinessOS.Application.Ports;
using BusinessOS.Domain.Features;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Features.Commands;

public static class FeatureFlagMappers
{
    public static FeatureFlagDto ToDto(FeatureFlag f) => new(
        f.Id, f.TenantId, f.Key, f.IsEnabled, f.Config, f.CreatedAt);
}

// ── Set Feature Flag ────────────────────────────────────────────
public sealed record SetFeatureFlagCommand(
    string Key, bool IsEnabled, string? Config)
    : IRequest<Result<FeatureFlagDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetFeatureFlagCommandHandler
    : IRequestHandler<SetFeatureFlagCommand, Result<FeatureFlagDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IFeatureFlagRepository _flags;

    public SetFeatureFlagCommandHandler(ITenantContext tenantContext, IFeatureFlagRepository flags)
    {
        _tenantContext = tenantContext;
        _flags = flags;
    }

    public async Task<Result<FeatureFlagDto>> Handle(
        SetFeatureFlagCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var flag = await _flags.GetAsync(tenantId, command.Key, cancellationToken);
        if (flag is null)
        {
            flag = FeatureFlag.Create(tenantId, command.Key, command.IsEnabled);
            if (command.IsEnabled && command.Config is not null)
                flag.Enable(command.Config);
            await _flags.AddAsync(flag, cancellationToken);
        }
        else
        {
            if (command.IsEnabled)
                flag.Enable(command.Config);
            else
                flag.Disable();
            await _flags.UpdateAsync(flag, cancellationToken);
        }

        return Result.Success(FeatureFlagMappers.ToDto(flag));
    }
}
