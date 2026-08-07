using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Queries;

public sealed record GetCurrentUserQuery : IRequest<Result<UserDto>>;

public sealed class GetCurrentUserQueryHandler : IRequestHandler<GetCurrentUserQuery, Result<UserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;

    public GetCurrentUserQueryHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _users = users;
        _roles = roles;
    }

    public async Task<Result<UserDto>> Handle(GetCurrentUserQuery request, CancellationToken cancellationToken)
    {
        if (_tenantContext.UserId is null)
        {
            return Error.Unauthorized("Not authenticated.");
        }

        var user = await _users.GetByIdWithRolesAsync(_tenantContext.TenantId, _tenantContext.UserId.Value, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var permissions = new List<string>();
        foreach (var roleId in user.Roles.Select(r => r.Id))
        {
            permissions.AddRange(await _roles.GetPermissionsAsync(_tenantContext.TenantId, roleId, cancellationToken));
        }

        var result = new UserDto(
            user.Id,
            user.TenantId,
            user.Email,
            user.FullName,
            user.Phone,
            user.IsActive,
            user.EmailVerified,
            permissions.Distinct().ToArray());

        return Result.Success(result);
    }
}
