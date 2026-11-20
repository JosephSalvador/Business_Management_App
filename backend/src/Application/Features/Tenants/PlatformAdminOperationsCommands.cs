using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

// ── 1. List Tenant Users ─────────────────────────────────────────────────────
public sealed record ListTenantUsersAdminQuery(Guid TenantId)
    : IRequest<Result<IReadOnlyList<TenantUserAdminDto>>>;

public sealed class ListTenantUsersAdminQueryHandler
    : IRequestHandler<ListTenantUsersAdminQuery, Result<IReadOnlyList<TenantUserAdminDto>>>
{
    private readonly IFleetAdminRepository _fleet;

    public ListTenantUsersAdminQueryHandler(IFleetAdminRepository fleet) => _fleet = fleet;

    public async Task<Result<IReadOnlyList<TenantUserAdminDto>>> Handle(
        ListTenantUsersAdminQuery request, CancellationToken cancellationToken)
    {
        var users = await _fleet.ListTenantUsersAsync(request.TenantId, cancellationToken);
        return Result.Success(users);
    }
}

// ── 2. Reset Tenant User Password ────────────────────────────────────────────
public sealed record ResetTenantUserPasswordAdminCommand(
    Guid TenantId,
    Guid UserId,
    string NewPassword) : IRequest<Result>;

public sealed class ResetTenantUserPasswordAdminCommandHandler
    : IRequestHandler<ResetTenantUserPasswordAdminCommand, Result>
{
    private readonly IFleetAdminRepository _fleet;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public ResetTenantUserPasswordAdminCommandHandler(
        IFleetAdminRepository fleet,
        IPasswordHasher passwordHasher,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _fleet = fleet;
        _passwordHasher = passwordHasher;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        ResetTenantUserPasswordAdminCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Trim().Length < 8)
        {
            return Result.Failure(Error.Validation("Password must be at least 8 characters."));
        }

        var user = await _fleet.GetTenantUserByIdAsync(request.TenantId, request.UserId, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.NotFound($"User {request.UserId} was not found in tenant {request.TenantId}."));
        }

        var hash = _passwordHasher.Hash(request.NewPassword.Trim());
        user.ChangePassword(hash);
        user.ResetFailedLogins();
        await _fleet.UpdateUserAsync(user, cancellationToken);
        await _fleet.RevokeAllUserRefreshTokensAsync(request.TenantId, request.UserId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.ResetUserPassword",
                "User",
                user.Id.ToString(),
                $"Password reset and sessions revoked for {user.Email} by Platform Operator"),
            cancellationToken);

        return Result.Success();
    }
}

// ── 3. Lock / Unlock (Activate / Deactivate) Tenant User ─────────────────────
public sealed record ToggleTenantUserStatusAdminCommand(
    Guid TenantId,
    Guid UserId,
    bool IsActive) : IRequest<Result>;

public sealed class ToggleTenantUserStatusAdminCommandHandler
    : IRequestHandler<ToggleTenantUserStatusAdminCommand, Result>
{
    private readonly IFleetAdminRepository _fleet;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public ToggleTenantUserStatusAdminCommandHandler(
        IFleetAdminRepository fleet,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _fleet = fleet;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        ToggleTenantUserStatusAdminCommand request, CancellationToken cancellationToken)
    {
        var user = await _fleet.GetTenantUserByIdAsync(request.TenantId, request.UserId, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.NotFound($"User {request.UserId} was not found in tenant {request.TenantId}."));
        }

        if (request.IsActive)
        {
            user.Activate();
            user.ResetFailedLogins();
        }
        else
        {
            user.Deactivate();
            await _fleet.RevokeAllUserRefreshTokensAsync(request.TenantId, request.UserId, cancellationToken);
        }

        await _fleet.UpdateUserAsync(user, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                request.IsActive ? "PlatformOperator.UnlockUser" : "PlatformOperator.LockUser",
                "User",
                user.Id.ToString(),
                $"{user.Email} {(request.IsActive ? "unlocked/activated" : "locked/deactivated")} by Platform Operator"),
            cancellationToken);

        return Result.Success();
    }
}

// ── 4. Force Logout Tenant User ──────────────────────────────────────────────
public sealed record ForceLogoutTenantUserAdminCommand(
    Guid TenantId,
    Guid UserId) : IRequest<Result<int>>;

public sealed class ForceLogoutTenantUserAdminCommandHandler
    : IRequestHandler<ForceLogoutTenantUserAdminCommand, Result<int>>
{
    private readonly IFleetAdminRepository _fleet;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public ForceLogoutTenantUserAdminCommandHandler(
        IFleetAdminRepository fleet,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _fleet = fleet;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<int>> Handle(
        ForceLogoutTenantUserAdminCommand request, CancellationToken cancellationToken)
    {
        var user = await _fleet.GetTenantUserByIdAsync(request.TenantId, request.UserId, cancellationToken);
        if (user is null)
        {
            return Result<int>.Failure(Error.NotFound($"User {request.UserId} was not found."));
        }

        var revoked = await _fleet.RevokeAllUserRefreshTokensAsync(request.TenantId, request.UserId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.ForceLogoutUser",
                "User",
                user.Id.ToString(),
                $"Revoked {revoked} active session(s) for {user.Email}"),
            cancellationToken);

        return Result.Success(revoked);
    }
}

// ── 5. Suspend / Reactivate Tenant ───────────────────────────────────────────
public sealed record UpdateTenantStatusAdminCommand(
    Guid TenantId,
    bool IsActive,
    string? Reason) : IRequest<Result>;

public sealed class UpdateTenantStatusAdminCommandHandler
    : IRequestHandler<UpdateTenantStatusAdminCommand, Result>
{
    private readonly IFleetAdminRepository _fleet;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantStatusAdminCommandHandler(
        IFleetAdminRepository fleet,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _fleet = fleet;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        UpdateTenantStatusAdminCommand request, CancellationToken cancellationToken)
    {
        var tenant = await _fleet.GetTenantByIdAsync(request.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Result.Failure(Error.NotFound($"Tenant {request.TenantId} was not found."));
        }

        if (request.IsActive) tenant.Activate();
        else tenant.Deactivate();

        await _fleet.UpdateTenantAsync(tenant, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                request.IsActive ? "PlatformOperator.ReactivateTenant" : "PlatformOperator.SuspendTenant",
                "Tenant",
                tenant.Id.ToString(),
                $"{(request.IsActive ? "Reactivated" : "Suspended")} {tenant.Name}. Reason: {request.Reason ?? "Platform action"}"),
            cancellationToken);

        return Result.Success();
    }
}

// ── 6. Update Tenant Tags & 35,000 TZS Training/Installation Status ───────────
public sealed record UpdateTenantOnboardingAdminCommand(
    Guid TenantId,
    string? Tags,
    bool TrainingPaid) : IRequest<Result>;

public sealed class UpdateTenantOnboardingAdminCommandHandler
    : IRequestHandler<UpdateTenantOnboardingAdminCommand, Result>
{
    private readonly IFleetAdminRepository _fleet;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantOnboardingAdminCommandHandler(
        IFleetAdminRepository fleet,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _fleet = fleet;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        UpdateTenantOnboardingAdminCommand request, CancellationToken cancellationToken)
    {
        var tenant = await _fleet.GetTenantByIdAsync(request.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Result.Failure(Error.NotFound($"Tenant {request.TenantId} was not found."));
        }

        tenant.UpdateTags(request.Tags);
        tenant.SetTrainingPaid(request.TrainingPaid);
        await _fleet.UpdateTenantAsync(tenant, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.UpdateTenantOnboarding",
                "Tenant",
                tenant.Id.ToString(),
                $"Updated tags='{tenant.Tags ?? ""}', trainingPaid={tenant.TrainingPaid}"),
            cancellationToken);

        return Result.Success();
    }
}

// ── 7. Bulk CSV Product Import for Tenant Onboarding ─────────────────────────
public sealed record BulkImportTenantProductsAdminCommand(
    Guid TenantId,
    IReadOnlyList<BulkImportProductItemDto> Items) : IRequest<Result<BulkImportResultDto>>;

public sealed class BulkImportTenantProductsAdminCommandHandler
    : IRequestHandler<BulkImportTenantProductsAdminCommand, Result<BulkImportResultDto>>
{
    private readonly IOmniTenantCatalogRepository _catalog;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public BulkImportTenantProductsAdminCommandHandler(
        IOmniTenantCatalogRepository catalog,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _catalog = catalog;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<BulkImportResultDto>> Handle(
        BulkImportTenantProductsAdminCommand request, CancellationToken cancellationToken)
    {
        if (request.Items is null || request.Items.Count == 0)
        {
            return Result<BulkImportResultDto>.Failure(Error.Validation("At least one product row is required."));
        }

        if (request.Items.Count > 500)
        {
            return Result<BulkImportResultDto>.Failure(Error.Validation("Maximum 500 products per import batch."));
        }

        var result = await _catalog.BulkImportProductsAsync(
            request.TenantId, request.Items, _tenantContext.UserId, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.BulkImportProducts",
                "Product",
                request.TenantId.ToString(),
                $"Bulk imported {result.CreatedCount} products ({result.SkippedCount} skipped) by Platform Operator"),
            cancellationToken);

        return Result.Success(result);
    }
}

// ── 8. List Platform Audit Logs ──────────────────────────────────────────────
public sealed record ListPlatformAuditLogsAdminQuery(
    Guid? TenantId = null,
    string? Search = null,
    int Page = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<PlatformAuditLogDto>>>;

public sealed class ListPlatformAuditLogsAdminQueryHandler
    : IRequestHandler<ListPlatformAuditLogsAdminQuery, Result<PagedResult<PlatformAuditLogDto>>>
{
    private readonly IFleetAdminRepository _fleet;

    public ListPlatformAuditLogsAdminQueryHandler(IFleetAdminRepository fleet) => _fleet = fleet;

    public async Task<Result<PagedResult<PlatformAuditLogDto>>> Handle(
        ListPlatformAuditLogsAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _fleet.ListPlatformAuditLogsAsync(
            request.TenantId, request.Search, request.Page, request.PageSize, cancellationToken);
        return Result.Success(result);
    }
}
