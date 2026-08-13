using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Queries;

public sealed record ListUsersQuery(int Page, int PageSize) : IRequest<Result<PagedResult<IdentityUserDto>>>;

public sealed class ListUsersQueryHandler : IRequestHandler<ListUsersQuery, Result<PagedResult<IdentityUserDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;

    public ListUsersQueryHandler(ITenantContext tenantContext, IUserRepository users)
    {
        _tenantContext = tenantContext;
        _users = users;
    }

    public async Task<Result<PagedResult<IdentityUserDto>>> Handle(
        ListUsersQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var users = await _users.ListAsync(tenantId, request.Page, request.PageSize, cancellationToken);
        var total = await _users.CountAsync(tenantId, cancellationToken);

        var items = users.Select(UserMappers.ToDto).ToList();
        return Result.Success(new PagedResult<IdentityUserDto>(items, request.Page, request.PageSize, total));
    }
}
