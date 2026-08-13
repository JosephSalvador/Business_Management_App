using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Queries;

public sealed record GetRoleQuery(Guid Id) : IRequest<Result<RoleDto>>;

public sealed class GetRoleQueryHandler : IRequestHandler<GetRoleQuery, Result<RoleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public GetRoleQueryHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result<RoleDto>> Handle(GetRoleQuery request, CancellationToken cancellationToken)
    {
        var role = await _roles.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (role is null)
        {
            return Error.NotFound("Role not found.");
        }

        return Result.Success(RoleMappers.ToDto(role));
    }
}
