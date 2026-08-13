using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Queries;

public sealed record GetUserBranchesQuery(Guid Id) : IRequest<Result<IReadOnlyList<UserBranchDto>>>;

public sealed class GetUserBranchesQueryHandler
    : IRequestHandler<GetUserBranchesQuery, Result<IReadOnlyList<UserBranchDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IBranchRepository _branches;

    public GetUserBranchesQueryHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _users = users;
        _branches = branches;
    }

    public async Task<Result<IReadOnlyList<UserBranchDto>>> Handle(
        GetUserBranchesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var user = await _users.GetByIdAsync(tenantId, request.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var branches = await _branches.ListByIdsAsync(tenantId, user.Branches.Select(b => b.BranchId), cancellationToken);
        var branchLookup = branches.ToDictionary(b => b.Id);

        var result = user.Branches
            .Where(b => branchLookup.ContainsKey(b.BranchId))
            .Select(b => UserMappers.ToBranchDto(branchLookup[b.BranchId], b.IsDefault))
            .OrderBy(b => b.BranchCode)
            .ToArray();

        return Result.Success<IReadOnlyList<UserBranchDto>>(result);
    }
}
