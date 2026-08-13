using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Commands;

public sealed record CreateRoleCommand(
    string Name,
    string? Description) : IRequest<Result<RoleDto>>;

public sealed class CreateRoleCommandHandler : IRequestHandler<CreateRoleCommand, Result<RoleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public CreateRoleCommandHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result<RoleDto>> Handle(CreateRoleCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var name = command.Name.Trim();
        if (await _roles.GetByNameAsync(tenantId, name, cancellationToken) is not null)
        {
            return Error.Conflict("A role with this name already exists.");
        }

        var role = Role.Create(tenantId, name, isSystem: false, command.Description);
        await _roles.AddAsync(role, cancellationToken);
        return Result.Success(RoleMappers.ToDto(role));
    }
}
