using BusinessOS.Application.Features.Features.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Features.Queries;

// ── Get Feature Flag ────────────────────────────────────────────
public sealed record GetFeatureFlagQuery(string Key)
    : IRequest<Result<FeatureFlagDto?>>, IRequiresTenantAdvisoryLock;

public sealed class GetFeatureFlagQueryHandler
    : IRequestHandler<GetFeatureFlagQuery, Result<FeatureFlagDto?>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IFeatureFlagRepository _flags;

    public GetFeatureFlagQueryHandler(ITenantContext tenantContext, IFeatureFlagRepository flags)
    {
        _tenantContext = tenantContext;
        _flags = flags;
    }

    public async Task<Result<FeatureFlagDto?>> Handle(
        GetFeatureFlagQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var flag = await _flags.GetAsync(tenantId, query.Key, cancellationToken);
        // Resource-identifying GET driven by a path key: a missing flag is "not found".
        if (flag is null)
            return Error.NotFound("Feature flag not found.");

        return Result.Success<FeatureFlagDto?>(FeatureFlagMappers.ToDto(flag));
    }
}

// ── List Feature Flags ──────────────────────────────────────────
public sealed record ListFeatureFlagsQuery()
    : IRequest<Result<IReadOnlyList<FeatureFlagDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListFeatureFlagsQueryHandler
    : IRequestHandler<ListFeatureFlagsQuery, Result<IReadOnlyList<FeatureFlagDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IFeatureFlagRepository _flags;

    public ListFeatureFlagsQueryHandler(ITenantContext tenantContext, IFeatureFlagRepository flags)
    {
        _tenantContext = tenantContext;
        _flags = flags;
    }

    public async Task<Result<IReadOnlyList<FeatureFlagDto>>> Handle(
        ListFeatureFlagsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var flags = await _flags.ListAsync(tenantId, cancellationToken);
        return Result.Success<IReadOnlyList<FeatureFlagDto>>(
            flags.Select(FeatureFlagMappers.ToDto).ToList());
    }
}
