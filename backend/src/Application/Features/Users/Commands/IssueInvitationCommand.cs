using System.Security.Cryptography;
using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record IssueInvitationCommand : IRequest<Result<InvitationDto>>;

public sealed record InvitationDto(string Code, DateTime ExpiresAtUtc);

/// <summary>
/// Issues a one-time staff invitation code for the current tenant. The raw code
/// is returned to the caller exactly once so the owner can share it; only its
/// SHA-256 hash is persisted. A staff member redeems it at registration via
/// RegisterStaffCommand and is attached to this tenant with the Staff role.
/// </summary>
public sealed class IssueInvitationCommandHandler : IRequestHandler<IssueInvitationCommand, Result<InvitationDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenants;
    private readonly IInvitationCodeRepository _codes;
    private readonly SecurityOptions _security;

    public IssueInvitationCommandHandler(
        ITenantContext tenantContext,
        ITenantRepository tenants,
        IInvitationCodeRepository codes,
        IOptions<SecurityOptions> security)
    {
        _tenantContext = tenantContext;
        _tenants = tenants;
        _codes = codes;
        _security = security.Value;
    }

    public async Task<Result<InvitationDto>> Handle(
        IssueInvitationCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(_tenantContext.TenantId, cancellationToken);
        if (tenant is null || tenant.OnboardingCompletedAt is null)
        {
            return Error.Validation("Complete business setup before inviting staff.");
        }

        const int codeLength = 8;
        var codeChars = new char[codeLength];
        for (var i = 0; i < codeLength; i++)
        {
            codeChars[i] = (char)('A' + RandomNumberGenerator.GetInt32(0, 26));
        }
        var code = new string(codeChars);

        var expiresAt = DateTime.UtcNow.AddHours(_security.InvitationCodeTtlHours);
        await _codes.AddAsync(
            InvitationCode.Create(_tenantContext.TenantId, CodeHasher.Hash(code), expiresAt),
            cancellationToken);

        return Result.Success(new InvitationDto(code, expiresAt));
    }
}
