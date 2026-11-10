using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ListPlatformOperatorsQuery : IRequest<Result<IReadOnlyList<PlatformOperatorDto>>>;

public sealed class ListPlatformOperatorsQueryHandler : IRequestHandler<ListPlatformOperatorsQuery, Result<IReadOnlyList<PlatformOperatorDto>>>
{
    private readonly IPlatformTeamRepository _team;

    public ListPlatformOperatorsQueryHandler(IPlatformTeamRepository team) => _team = team;

    public async Task<Result<IReadOnlyList<PlatformOperatorDto>>> Handle(
        ListPlatformOperatorsQuery request, CancellationToken cancellationToken)
    {
        var items = await _team.ListPlatformOperatorsAsync(cancellationToken);
        return Result.Success(items);
    }
}

public sealed record AssignPlatformRoleCommand(
    string Email,
    string Role) : IRequest<Result>;

public sealed class AssignPlatformRoleCommandHandler : IRequestHandler<AssignPlatformRoleCommand, Result>
{
    private readonly IPlatformTeamRepository _team;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public AssignPlatformRoleCommandHandler(
        IPlatformTeamRepository team,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _team = team;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        AssignPlatformRoleCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return Error.Validation("Email is required.");
        }

        if (!Enum.TryParse<PlatformRoleType>(request.Role, true, out var roleType) || roleType == PlatformRoleType.None)
        {
            return Error.Validation("Valid role (PlatformStaff or PlatformSuperAdmin) is required.");
        }

        var user = await _team.FindUserByEmailAsync(request.Email, cancellationToken);
        if (user is null)
        {
            return Error.NotFound($"User with email '{request.Email}' is not registered yet. Please have them register first.");
        }

        await _team.AssignPlatformRoleAsync(user.Id, roleType, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                user.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.AssignRole",
                "PlatformOperator",
                user.Id.ToString(),
                $"Platform role {roleType} granted to {user.Email}"),
            cancellationToken);

        return Result.Success();
    }
}

public sealed record RevokePlatformRoleCommand(Guid OperatorId) : IRequest<Result>;

public sealed class RevokePlatformRoleCommandHandler : IRequestHandler<RevokePlatformRoleCommand, Result>
{
    private readonly IPlatformTeamRepository _team;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public RevokePlatformRoleCommandHandler(
        IPlatformTeamRepository team,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _team = team;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        RevokePlatformRoleCommand request, CancellationToken cancellationToken)
    {
        await _team.RevokePlatformRoleAsync(request.OperatorId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                Guid.Empty,
                _tenantContext.UserId,
                "PlatformOperator.RevokeRole",
                "PlatformOperator",
                request.OperatorId.ToString(),
                $"Platform operator {request.OperatorId} access revoked"),
            cancellationToken);

        return Result.Success();
    }
}
