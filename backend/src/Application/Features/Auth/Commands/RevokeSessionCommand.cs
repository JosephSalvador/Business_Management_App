using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record RevokeSessionCommand(string RefreshToken) : IRequest<Result>;

public sealed class RevokeSessionCommandHandler : IRequestHandler<RevokeSessionCommand, Result>
{
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ITokenService _tokenService;

    public RevokeSessionCommandHandler(
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        ITokenService tokenService)
    {
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _tokenService = tokenService;
    }

    public async Task<Result> Handle(RevokeSessionCommand command, CancellationToken cancellationToken)
    {
        var tokenHash = _tokenService.HashRefreshToken(command.RefreshToken);
        var stored = await _refreshTokens.GetByHashAsync(tokenHash, cancellationToken);

        if (stored is null)
        {
            return Result.Success();
        }

        if (stored.RevokedAt is null)
        {
            stored.Revoke();
            await _auditLogs.AddAsync(AuditLog.Create(
                stored.TenantId,
                stored.UserId,
                "Auth.Logout",
                "User",
                stored.UserId.ToString()),
                cancellationToken);
        }

        return Result.Success();
    }
}
