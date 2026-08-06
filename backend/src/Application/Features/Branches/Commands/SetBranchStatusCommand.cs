using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Features.Branches.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Branches.Commands;

public sealed record SetBranchStatusCommand(Guid Id, bool IsActive) : IRequest<Result<BranchDto>>;

public sealed class SetBranchStatusCommandHandler
    : IRequestHandler<SetBranchStatusCommand, Result<BranchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;

    public SetBranchStatusCommandHandler(ITenantContext tenantContext, IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _branches = branches;
    }

    public async Task<Result<BranchDto>> Handle(
        SetBranchStatusCommand command, CancellationToken cancellationToken)
    {
        var branch = await _branches.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (branch is null)
        {
            return Error.NotFound("Branch not found.");
        }

        if (command.IsActive)
        {
            branch.Activate();
        }
        else
        {
            branch.Deactivate();
        }

        return Result.Success(ListBranchesQueryHandler.ToDto(branch));
    }
}
