using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Branches.Queries;

public sealed record ListBranchesQuery(int Page, int PageSize) : IRequest<Result<PagedResult<BranchDto>>>;

public sealed class ListBranchesQueryHandler
    : IRequestHandler<ListBranchesQuery, Result<PagedResult<BranchDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;

    public ListBranchesQueryHandler(ITenantContext tenantContext, IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _branches = branches;
    }

    public async Task<Result<PagedResult<BranchDto>>> Handle(
        ListBranchesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var branches = await _branches.ListAsync(tenantId, request.Page, request.PageSize, cancellationToken);
        var total = await _branches.CountAsync(tenantId, cancellationToken);

        var items = branches.Select(ToDto).ToList();
        return Result.Success(new PagedResult<BranchDto>(items, request.Page, request.PageSize, total));
    }

    internal static BranchDto ToDto(Branch branch) => new(
        branch.Id,
        branch.TenantId,
        branch.Name,
        branch.Code,
        branch.Currency,
        branch.Address,
        branch.Phone,
        branch.Email,
        branch.IsActive,
        branch.CreatedAt,
        branch.UpdatedAt);
}
