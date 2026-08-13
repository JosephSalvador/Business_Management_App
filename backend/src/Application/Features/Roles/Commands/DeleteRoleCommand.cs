using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Commands;

public sealed record DeleteRoleCommand(Guid Id) : IRequest<Result>;

public sealed class DeleteRoleCommandHandler : IRequestHandler<DeleteRoleCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public DeleteRoleCommandHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result> Handle(DeleteRoleCommand command, CancellationToken cancellationToken)
    {
        var role = await _roles.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (role is null)
        {
            return Result.Failure(Error.NotFound("Role not found."));
        }

        if (role.IsSystem)
        {
            return Result.Failure(Error.Conflict("System roles cannot be deleted."));
        }

        role.Delete();
        await _roles.RemoveAsync(role, cancellationToken);
        return Result.Success();
    }
}
