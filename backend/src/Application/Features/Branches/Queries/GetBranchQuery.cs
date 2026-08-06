using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Branches.Queries;

public sealed record GetBranchQuery(Guid Id) : IRequest<Result<BranchDto>>;

public sealed class GetBranchQueryHandler : IRequestHandler<GetBranchQuery, Result<BranchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;

    public GetBranchQueryHandler(ITenantContext tenantContext, IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _branches = branches;
    }

    public async Task<Result<BranchDto>> Handle(GetBranchQuery request, CancellationToken cancellationToken)
    {
        var branch = await _branches.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (branch is null)
        {
            return Error.NotFound("Branch not found.");
        }

        return Result.Success(ListBranchesQueryHandler.ToDto(branch));
    }
}
