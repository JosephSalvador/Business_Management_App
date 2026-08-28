using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record UpdateUserCommand(Guid Id, string FullName, string? Phone) : IRequest<Result<IdentityUserDto>>;

public sealed class UpdateUserCommandHandler : IRequestHandler<UpdateUserCommand, Result<IdentityUserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;

    public UpdateUserCommandHandler(ITenantContext tenantContext, IUserRepository users)
    {
        _tenantContext = tenantContext;
        _users = users;
    }

    public async Task<Result<IdentityUserDto>> Handle(
        UpdateUserCommand command, CancellationToken cancellationToken)
    {
        var user = await _users.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var phone = PhoneNumber.Normalize(command.Phone);
        if (command.Phone is not null && phone is null)
        {
            return Error.Validation("Phone number is not valid.");
        }

        if (phone is not null)
        {
            var existing = await _users.GetByPhoneAsync(phone, cancellationToken);
            if (existing is not null && existing.Id != user.Id)
            {
                return Error.Conflict("Phone number is already registered.");
            }
        }

        user.UpdateProfile(command.FullName.Trim(), phone);
        return Result.Success(UserMappers.ToDto(user));
    }
}
