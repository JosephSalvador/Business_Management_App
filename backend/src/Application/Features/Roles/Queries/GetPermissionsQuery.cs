using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Queries;

public sealed record GetPermissionsQuery : IRequest<Result<IReadOnlyList<PermissionDto>>>;

public sealed class GetPermissionsQueryHandler : IRequestHandler<GetPermissionsQuery, Result<IReadOnlyList<PermissionDto>>>
{
    private readonly IPermissionRepository _permissions;

    public GetPermissionsQueryHandler(IPermissionRepository permissions)
    {
        _permissions = permissions;
    }

    public async Task<Result<IReadOnlyList<PermissionDto>>> Handle(
        GetPermissionsQuery request, CancellationToken cancellationToken)
    {
        var permissions = await _permissions.ListAsync(cancellationToken);
        return Result.Success<IReadOnlyList<PermissionDto>>(
            permissions.Select(RoleMappers.ToPermissionDto).ToList());
    }
}
