using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Queries;

public sealed record GetRolePermissionsQuery(Guid RoleId) : IRequest<Result<IReadOnlyList<string>>>;

public sealed class GetRolePermissionsQueryHandler : IRequestHandler<GetRolePermissionsQuery, Result<IReadOnlyList<string>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public GetRolePermissionsQueryHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result<IReadOnlyList<string>>> Handle(
        GetRolePermissionsQuery request, CancellationToken cancellationToken)
    {
        var exists = await _roles.GetByIdAsync(_tenantContext.TenantId, request.RoleId, cancellationToken);
        if (exists is null)
        {
            return Error.NotFound("Role not found.");
        }

        var permissions = await _roles.GetPermissionsAsync(_tenantContext.TenantId, request.RoleId, cancellationToken);
        return Result.Success<IReadOnlyList<string>>(permissions.ToList());
    }
}
