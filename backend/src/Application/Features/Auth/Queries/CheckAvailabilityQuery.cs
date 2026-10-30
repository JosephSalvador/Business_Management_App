using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Queries;

public sealed record CheckAvailabilityQuery(
    string? Email,
    string? Phone) : IRequest<Result<AvailabilityResultDto>>;

public sealed class CheckAvailabilityQueryHandler
    : IRequestHandler<CheckAvailabilityQuery, Result<AvailabilityResultDto>>
{
    private readonly IUserRepository _users;

    public CheckAvailabilityQueryHandler(IUserRepository users)
    {
        _users = users;
    }

    public async Task<Result<AvailabilityResultDto>> Handle(
        CheckAvailabilityQuery query,
        CancellationToken cancellationToken)
    {
        var emailAvailable = true;
        if (!string.IsNullOrWhiteSpace(query.Email))
        {
            var normalizedEmail = query.Email.Trim().ToLowerInvariant();
            emailAvailable = (await _users.GetByEmailAsync(normalizedEmail, cancellationToken)) is null;
        }

        var phoneAvailable = true;
        if (!string.IsNullOrWhiteSpace(query.Phone))
        {
            var normalizedPhone = PhoneNumber.Normalize(query.Phone);
            if (normalizedPhone is not null)
            {
                phoneAvailable = (await _users.GetByPhoneAsync(normalizedPhone, cancellationToken)) is null;
            }
        }

        return Result.Success(new AvailabilityResultDto(emailAvailable, phoneAvailable));
    }
}
