using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record SetUserBranchesCommand(
    Guid Id,
    IReadOnlyList<Guid> BranchIds,
    Guid? DefaultBranchId) : IRequest<Result<IReadOnlyList<UserBranchDto>>>;

public sealed class SetUserBranchesCommandHandler
    : IRequestHandler<SetUserBranchesCommand, Result<IReadOnlyList<UserBranchDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IBranchRepository _branches;

    public SetUserBranchesCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _users = users;
        _branches = branches;
    }

    public async Task<Result<IReadOnlyList<UserBranchDto>>> Handle(
        SetUserBranchesCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var user = await _users.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var branchIds = command.BranchIds.Distinct().ToArray();
        if (branchIds.Length != command.BranchIds.Count)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["BranchIds"] = new[] { "Branch ids must not contain duplicates." },
            });
        }

        var branches = await _branches.ListByIdsAsync(tenantId, branchIds, cancellationToken);
        if (branches.Count != branchIds.Length)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["BranchIds"] = new[] { "One or more branches do not exist in this tenant." },
            });
        }

        user.AssignBranches(
            branchIds.Select(branchId => new UserBranchAssignment(branchId, branchId == command.DefaultBranchId)),
            assignedBy: _tenantContext.UserId ?? Guid.Empty,
            assignedAt: DateTime.UtcNow);

        var dto = branches
            .Select(b => UserMappers.ToBranchDto(b, b.Id == command.DefaultBranchId))
            .OrderBy(b => b.BranchCode)
            .ToArray();

        return Result.Success<IReadOnlyList<UserBranchDto>>(dto);
    }
}
