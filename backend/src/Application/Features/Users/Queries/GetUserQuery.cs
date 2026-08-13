using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Queries;

public sealed record GetUserQuery(Guid Id) : IRequest<Result<IdentityUserDto>>;

public sealed class GetUserQueryHandler : IRequestHandler<GetUserQuery, Result<IdentityUserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;

    public GetUserQueryHandler(ITenantContext tenantContext, IUserRepository users)
    {
        _tenantContext = tenantContext;
        _users = users;
    }

    public async Task<Result<IdentityUserDto>> Handle(GetUserQuery request, CancellationToken cancellationToken)
    {
        var user = await _users.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        return Result.Success(UserMappers.ToDto(user));
    }
}
