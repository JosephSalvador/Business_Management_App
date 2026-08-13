using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Queries;

public sealed record ListRolesQuery : IRequest<Result<IReadOnlyList<RoleDto>>>;

public sealed class ListRolesQueryHandler : IRequestHandler<ListRolesQuery, Result<IReadOnlyList<RoleDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public ListRolesQueryHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result<IReadOnlyList<RoleDto>>> Handle(
        ListRolesQuery request, CancellationToken cancellationToken)
    {
        var roles = await _roles.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<RoleDto>>(roles.Select(RoleMappers.ToDto).ToList());
    }
}
