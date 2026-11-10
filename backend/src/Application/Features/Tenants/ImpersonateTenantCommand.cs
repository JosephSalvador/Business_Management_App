using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ImpersonationResultDto(
    string AccessToken,
    Guid TenantId,
    string TenantName,
    string LaunchUrl);

// ── 1. Impersonate Tenant ─────────────────────────────────────────
public sealed record ImpersonateTenantCommand(Guid TenantId) : IRequest<Result<ImpersonationResultDto>>;

public sealed class ImpersonateTenantCommandHandler
    : IRequestHandler<ImpersonateTenantCommand, Result<ImpersonationResultDto>>
{
    private readonly BusinessDbContext _db;
    private readonly ITokenService _tokenService;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;
    private readonly IOptions<PlatformAdminOptions> _platformOptions;

    public ImpersonateTenantCommandHandler(
        BusinessDbContext db,
        ITokenService tokenService,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs,
        IOptions<PlatformAdminOptions> platformOptions)
    {
        _db = db;
        _tokenService = tokenService;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
        _platformOptions = platformOptions;
    }

    public async Task<Result<ImpersonationResultDto>> Handle(
        ImpersonateTenantCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.Id == command.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Error.NotFound("Tenant not found.");
        }

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        var operatorUser = await _db.Users.FirstOrDefaultAsync(u => u.Id == operatorUserId, cancellationToken);
        var operatorEmail = operatorUser?.Email ?? "platform.operator@jolinx.com";

        // Find primary administrator user in the tenant
        var primaryAdmin = await _db.Users
            .Include(u => u.Roles)
            .Where(u => u.TenantId == command.TenantId && u.IsActive)
            .OrderBy(u => u.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

        var targetUserId = primaryAdmin?.Id ?? Guid.NewGuid();
        var targetEmail = primaryAdmin?.Email ?? $"admin@{tenant.Name.ToLowerInvariant().Replace(" ", "")}.com";

        var extraClaims = new Dictionary<string, string>
        {
            ["impersonated_by"] = operatorEmail,
            ["is_impersonation"] = "true",
            ["impersonated_at"] = DateTime.UtcNow.ToString("o"),
            ["tenant_name"] = tenant.Name
        };

        var token = _tokenService.GenerateAccessToken(
            targetUserId,
            tenant.Id,
            targetEmail,
            PermissionNames.All,
            extraClaims);

        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.Impersonate",
            "Tenant",
            command.TenantId.ToString()),
            cancellationToken);

        var clientAppBase = _platformOptions.Value?.ClientAppUrl ?? "https://app.jolinx.com";
        var launchUrl = $"{clientAppBase.TrimEnd('/')}/?impersonate_token={token}&tenant_id={tenant.Id}";

        return Result.Success(new ImpersonationResultDto(
            token,
            tenant.Id,
            tenant.Name,
            launchUrl));
    }
}

// ── 2. Update Feature Flags for Tenant ────────────────────────────
public sealed record UpdateTenantFeaturesAdminCommand(
    Guid TenantId,
    IReadOnlyList<string> EnabledFeatures)
    : IRequest<Result<IReadOnlyList<string>>>;

public sealed class UpdateTenantFeaturesAdminCommandHandler
    : IRequestHandler<UpdateTenantFeaturesAdminCommand, Result<IReadOnlyList<string>>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ICacheService _cache;

    public UpdateTenantFeaturesAdminCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs,
        ICacheService cache)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
        _cache = cache;
    }

    public async Task<Result<IReadOnlyList<string>>> Handle(
        UpdateTenantFeaturesAdminCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.Id == command.TenantId, cancellationToken);
        if (tenant is null) return Error.NotFound("Tenant not found.");

        var existingFlags = await _db.FeatureFlags
            .Where(f => f.TenantId == command.TenantId)
            .ToListAsync(cancellationToken);

        var enabledSet = new HashSet<string>(command.EnabledFeatures, StringComparer.OrdinalIgnoreCase);

        foreach (var key in FeatureKeys.All)
        {
            var isDesired = enabledSet.Contains(key);
            var flag = existingFlags.FirstOrDefault(f => f.FeatureKey == key);

            if (flag is null)
            {
                var newFlag = FeatureFlag.Create(command.TenantId, key, isDesired);
                await _db.FeatureFlags.AddAsync(newFlag, cancellationToken);
            }
            else if (flag.IsEnabled != isDesired)
            {
                if (isDesired) flag.Enable(); else flag.Disable();
            }
        }

        await _db.SaveChangesAsync(cancellationToken);

        // Invalidate capabilities cache for the tenant
        await _cache.RemoveAsync($"tenant:capabilities:{command.TenantId}", cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.UpdateFeatures",
            "FeatureFlags",
            string.Join(",", command.EnabledFeatures)),
            cancellationToken);

        return Result.Success(command.EnabledFeatures);
    }
}
