using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Application.Features.Tenants;

public sealed record PlatformOperatorDetailDto(
    Guid Id,
    Guid UserId,
    string Email,
    string FullName,
    string? Phone,
    PlatformRoleType Role,
    bool IsActive,
    DateTime AssignedAtUtc,
    string? AssignedByEmail);

// ── List Platform Operators ─────────────────────────────────────
public sealed record ListPlatformOperatorsQuery : IRequest<Result<IReadOnlyList<PlatformOperatorDetailDto>>>;

public sealed class ListPlatformOperatorsQueryHandler
    : IRequestHandler<ListPlatformOperatorsQuery, Result<IReadOnlyList<PlatformOperatorDetailDto>>>
{
    private readonly BusinessDbContext _db;

    public ListPlatformOperatorsQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<IReadOnlyList<PlatformOperatorDetailDto>>> Handle(
        ListPlatformOperatorsQuery request, CancellationToken cancellationToken)
    {
        var operators = await _db.PlatformOperators
            .OrderByDescending(o => o.AssignedAtUtc)
            .ToListAsync(cancellationToken);

        var userIds = operators.Select(o => o.UserId)
            .Concat(operators.Select(o => o.AssignedByUserId))
            .Distinct()
            .ToList();

        var users = await _db.Users
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, cancellationToken);

        var list = operators.Select(o =>
        {
            users.TryGetValue(o.UserId, out var user);
            users.TryGetValue(o.AssignedByUserId, out var assignedByUser);

            return new PlatformOperatorDetailDto(
                o.Id,
                o.UserId,
                user?.Email ?? "unknown@user",
                user?.FullName ?? "Unknown",
                user?.Phone,
                o.Role,
                o.IsActive,
                o.AssignedAtUtc,
                assignedByUser?.Email);
        }).ToList();

        return Result.Success<IReadOnlyList<PlatformOperatorDetailDto>>(list);
    }
}

// ── Invite / Assign Platform Staff ──────────────────────────────
public sealed record AssignPlatformRoleCommand(
    string Email,
    PlatformRoleType Role)
    : IRequest<Result<PlatformOperatorDetailDto>>;

public sealed class AssignPlatformRoleCommandHandler
    : IRequestHandler<AssignPlatformRoleCommand, Result<PlatformOperatorDetailDto>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public AssignPlatformRoleCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<PlatformOperatorDetailDto>> Handle(
        AssignPlatformRoleCommand command, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Email))
        {
            return Error.Validation("Email is required.");
        }

        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == normalizedEmail, cancellationToken);
        if (user is null)
        {
            return Error.NotFound($"No registered user found with email '{command.Email}'. The user must register first.");
        }

        var operatorUserId = _tenantContext.UserId ?? user.Id;
        var existing = await _db.PlatformOperators.FirstOrDefaultAsync(o => o.UserId == user.Id, cancellationToken);

        if (existing is null)
        {
            existing = PlatformOperator.Create(user.Id, command.Role, operatorUserId);
            await _db.PlatformOperators.AddAsync(existing, cancellationToken);
        }
        else
        {
            existing.ChangeRole(command.Role, operatorUserId);
            existing.Reactivate();
        }

        await _db.SaveChangesAsync(cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            operatorUserId,
            "Platform.AssignRole",
            "PlatformOperator",
            existing.Id.ToString()),
            cancellationToken);

        return Result.Success(new PlatformOperatorDetailDto(
            existing.Id,
            user.Id,
            user.Email,
            user.FullName,
            user.Phone,
            existing.Role,
            existing.IsActive,
            existing.AssignedAtUtc,
            _tenantContext.UserAgent));
    }
}

// ── Revoke Platform Staff ───────────────────────────────────────
public sealed record RevokePlatformRoleCommand(Guid OperatorId) : IRequest<Result<bool>>;

public sealed class RevokePlatformRoleCommandHandler
    : IRequestHandler<RevokePlatformRoleCommand, Result<bool>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public RevokePlatformRoleCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<bool>> Handle(
        RevokePlatformRoleCommand command, CancellationToken cancellationToken)
    {
        var op = await _db.PlatformOperators.FirstOrDefaultAsync(o => o.Id == command.OperatorId, cancellationToken);
        if (op is null)
        {
            return Error.NotFound("Platform operator not found.");
        }

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        if (op.UserId == operatorUserId)
        {
            return Error.Conflict("You cannot revoke your own Platform SuperAdmin privileges.");
        }

        op.Deactivate();
        await _db.SaveChangesAsync(cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            Guid.Empty,
            operatorUserId,
            "Platform.RevokeRole",
            "PlatformOperator",
            op.Id.ToString()),
            cancellationToken);

        return Result.Success(true);
    }
}
