using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record UpdateMyProfileCommand(string FullName, string? Phone) : IRequest<Result<UserDto>>;

public sealed class UpdateMyProfileCommandHandler : IRequestHandler<UpdateMyProfileCommand, Result<UserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;

    public UpdateMyProfileCommandHandler(ITenantContext tenantContext, IUserRepository users)
    {
        _tenantContext = tenantContext;
        _users = users;
    }

    public async Task<Result<UserDto>> Handle(UpdateMyProfileCommand command, CancellationToken cancellationToken)
    {
        var userId = _tenantContext.UserId;
        if (userId is null)
        {
            return Error.Unauthorized("Not authenticated.");
        }

        var user = await _users.GetByIdAsync(_tenantContext.TenantId, userId.Value, cancellationToken);
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

        return Result.Success(new UserDto(
            user.Id,
            user.TenantId,
            user.Email,
            user.FullName,
            user.Phone,
            user.IsActive,
            user.EmailVerified,
            Array.Empty<string>()));
    }
}
