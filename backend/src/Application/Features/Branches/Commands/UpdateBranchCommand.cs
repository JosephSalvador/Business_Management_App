using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Features.Branches.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Branches.Commands;

public sealed record UpdateBranchCommand(
    Guid Id,
    string Name,
    string? Address,
    string? Phone,
    string? Email) : IRequest<Result<BranchDto>>;

public sealed class UpdateBranchCommandHandler : IRequestHandler<UpdateBranchCommand, Result<BranchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;

    public UpdateBranchCommandHandler(ITenantContext tenantContext, IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _branches = branches;
    }

    public async Task<Result<BranchDto>> Handle(UpdateBranchCommand command, CancellationToken cancellationToken)
    {
        var branch = await _branches.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (branch is null)
        {
            return Error.NotFound("Branch not found.");
        }

        branch.UpdateProfile(command.Name, command.Address, command.Phone, command.Email);
        return Result.Success(ListBranchesQueryHandler.ToDto(branch));
    }
}
