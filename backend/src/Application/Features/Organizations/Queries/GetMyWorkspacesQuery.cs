using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Organizations.Queries;

public sealed record GetMyWorkspacesQuery : IRequest<Result<IReadOnlyList<WorkspaceDto>>>;

public sealed class GetMyWorkspacesQueryHandler
    : IRequestHandler<GetMyWorkspacesQuery, Result<IReadOnlyList<WorkspaceDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenants;
    private readonly IUserRepository _users;

    public GetMyWorkspacesQueryHandler(
        ITenantContext tenantContext,
        ITenantRepository tenants,
        IUserRepository users)
    {
        _tenantContext = tenantContext;
        _tenants = tenants;
        _users = users;
    }

    public async Task<Result<IReadOnlyList<WorkspaceDto>>> Handle(
        GetMyWorkspacesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;
        if (tenantId == Guid.Empty || userId is null)
        {
            return Result.Success<IReadOnlyList<WorkspaceDto>>(Array.Empty<WorkspaceDto>());
        }

        var tenant = await _tenants.GetByIdAsync(tenantId, cancellationToken);
        if (tenant is null)
        {
            return Result.Success<IReadOnlyList<WorkspaceDto>>(Array.Empty<WorkspaceDto>());
        }

        var roles = Array.Empty<string>();
        var user = await _users.GetByIdWithRolesAsync(tenantId, userId.Value, cancellationToken);
        if (user is not null && user.IsActive)
        {
            roles = user.Roles.Select(r => r.Name).ToArray();
        }

        var workspace = new WorkspaceDto(
            tenant.Id,
            tenant.Name,
            tenant.Currency,
            tenant.CountryCode,
            tenant.BusinessType,
            tenant.OnboardingCompletedAt is not null,
            roles);

        return Result.Success<IReadOnlyList<WorkspaceDto>>(new[] { workspace });
    }
}
