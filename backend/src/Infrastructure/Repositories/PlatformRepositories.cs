using BusinessOS.Application.Features.Products.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Crm;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Finance;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Repositories;

public sealed class TenantRepository : ITenantRepository
{
    private readonly BusinessDbContext _db;

    public TenantRepository(BusinessDbContext db) => _db = db;

    public Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => _db.Tenants.FirstOrDefaultAsync(t => t.Id == id, cancellationToken);

    public Task<Tenant?> GetByNameAsync(string name, CancellationToken cancellationToken = default)
        => _db.Tenants.FirstOrDefaultAsync(t => t.Name == name, cancellationToken);

    public Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default)
        => _db.Tenants.AddAsync(tenant, cancellationToken).AsTask();

    public Task UpdateAsync(Tenant tenant, CancellationToken cancellationToken = default)
    {
        _db.Tenants.Update(tenant);
        return Task.CompletedTask;
    }
}

public sealed class BranchRepository : IBranchRepository
{
    private readonly BusinessDbContext _db;

    public BranchRepository(BusinessDbContext db) => _db = db;

    public Task<Branch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Branches.FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Id == id, cancellationToken);

    public Task<Branch?> GetByCodeAsync(Guid tenantId, string code, CancellationToken cancellationToken = default)
        => _db.Branches.FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Code == code, cancellationToken);

    public async Task<IReadOnlyList<Branch>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.Branches
            .Where(b => b.TenantId == tenantId)
            .OrderBy(b => b.Code)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Branch>> ListAllAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.Branches
            .Where(b => b.TenantId == tenantId)
            .OrderBy(b => b.Code)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Branch>> ListByIdsAsync(
        Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default)
    {
        var idList = ids.Distinct().ToArray();
        if (idList.Length == 0)
        {
            return Array.Empty<Branch>();
        }

        return await _db.Branches
            .AsNoTracking()
            .Where(b => b.TenantId == tenantId && idList.Contains(b.Id))
            .OrderBy(b => b.Code)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.Branches.CountAsync(b => b.TenantId == tenantId, cancellationToken);

    public Task AddAsync(Branch branch, CancellationToken cancellationToken = default)
        => _db.Branches.AddAsync(branch, cancellationToken).AsTask();
}

public sealed class UserRepository : IUserRepository
{
    private readonly BusinessDbContext _db;

    public UserRepository(BusinessDbContext db) => _db = db;

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
        => _db.Users
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

    public Task<User?> GetByPhoneAsync(string phone, CancellationToken cancellationToken = default)
        => _db.Users
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.Phone == phone, cancellationToken);

    public Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Users
            .AsSplitQuery()
            .Include(u => u.Roles)
            .Include(u => u.Branches)
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.Id == id, cancellationToken);

    public Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Users
            .AsNoTracking()
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.Id == id, cancellationToken);

    public async Task<IReadOnlyList<User>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.Users
            .AsNoTracking()
            .AsSplitQuery()
            .Where(u => u.TenantId == tenantId)
            .Include(u => u.Roles)
            .Include(u => u.Branches)
            .OrderBy(u => u.Email)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.Users.CountAsync(u => u.TenantId == tenantId, cancellationToken);

    public Task<int> CountActiveAdministratorsAsync(
        Guid tenantId, Guid excludeUserId, CancellationToken cancellationToken = default)
        => _db.Users.CountAsync(u =>
            u.TenantId == tenantId
            && u.Id != excludeUserId
            && u.IsActive
            && u.Roles.Any(r =>
                r.TenantId == tenantId && r.IsSystem && r.Name == SystemRoles.Administrator),
            cancellationToken);

    public Task AddAsync(User user, CancellationToken cancellationToken = default)
        => _db.Users.AddAsync(user, cancellationToken).AsTask();
}

public sealed class RoleRepository : IRoleRepository
{
    private readonly BusinessDbContext _db;

    public RoleRepository(BusinessDbContext db) => _db = db;

    public Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Roles
            .Include(r => r.Permissions)
            .FirstOrDefaultAsync(r => r.TenantId == tenantId && r.Id == id, cancellationToken);

    public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.Roles
            .AsNoTracking()
            .Include(r => r.Permissions)
            .FirstOrDefaultAsync(r => r.TenantId == tenantId && r.Name == name, cancellationToken);

    public async Task<IReadOnlyList<Role>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.Roles
            .AsNoTracking()
            .Where(r => r.TenantId == tenantId)
            .Include(r => r.Permissions)
            .OrderBy(r => r.Name)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Role>> GetManyByIdsAsync(
        Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default)
    {
        var idList = ids.Distinct().ToArray();
        if (idList.Length == 0)
        {
            return Array.Empty<Role>();
        }

        return await _db.Roles
            .Where(r => r.TenantId == tenantId && idList.Contains(r.Id))
            .Include(r => r.Permissions)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<string>> GetPermissionsAsync(
        Guid tenantId,
        Guid roleId,
        CancellationToken cancellationToken = default)
        => await _db.Roles
            .Where(r => r.TenantId == tenantId && r.Id == roleId)
            .SelectMany(r => r.Permissions.Select(p => p.Name))
            .Distinct()
            .OrderBy(p => p)
            .ToListAsync(cancellationToken);

    public Task AddAsync(Role role, CancellationToken cancellationToken = default)
        => _db.Roles.AddAsync(role, cancellationToken).AsTask();

    public Task RemoveAsync(Role role, CancellationToken cancellationToken = default)
    {
        _db.Roles.Remove(role);
        return Task.CompletedTask;
    }
}

public sealed class PermissionRepository : IPermissionRepository
{
    private readonly BusinessDbContext _db;

    public PermissionRepository(BusinessDbContext db) => _db = db;

    public async Task<IReadOnlyList<Permission>> ListAsync(CancellationToken cancellationToken = default)
        => await _db.Permissions
            .OrderBy(p => p.Name)
            .ToListAsync(cancellationToken);

    public Task<Permission?> GetByNameAsync(string name, CancellationToken cancellationToken = default)
        => _db.Permissions
            .FirstOrDefaultAsync(p => p.Name == name, cancellationToken);

    public async Task<IReadOnlyList<Permission>> ResolveByNamesAsync(
        IEnumerable<string> names,
        CancellationToken cancellationToken = default)
    {
        var nameList = names.Distinct().ToArray();
        return await _db.Permissions
            .Where(p => nameList.Contains(p.Name))
            .OrderBy(p => p.Name)
            .ToListAsync(cancellationToken);
    }
}

public sealed class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly BusinessDbContext _db;

    public RefreshTokenRepository(BusinessDbContext db) => _db = db;

    public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default)
        => _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == tokenHash, cancellationToken);

    public Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default)
        => _db.RefreshTokens.AddAsync(refreshToken, cancellationToken).AsTask();

    public async Task<IReadOnlyList<RefreshToken>> ListActiveByUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
        => await _db.RefreshTokens
            .AsNoTracking()
            .Where(t => t.TenantId == tenantId && t.UserId == userId && t.RevokedAt == null && t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync(cancellationToken);

    public async Task RevokeFamilyAsync(
        Guid familyId,
        Guid revokedByTokenId,
        CancellationToken cancellationToken = default)
    {
        var family = await _db.RefreshTokens
            .Where(t => t.FamilyId == familyId)
            .ToListAsync(cancellationToken);

        foreach (var token in family)
        {
            if (token.RevokedAt is null)
            {
                token.Revoke();
            }
        }
    }

    public async Task RevokeAllForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var tokens = await _db.RefreshTokens
            .Where(t => t.TenantId == tenantId && t.UserId == userId && t.RevokedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var token in tokens)
        {
            token.Revoke();
        }
    }

    public Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default)
        => _db.RefreshTokens
            .Where(t => t.RevokedAt != null || t.ExpiresAt < cutoff)
            .ExecuteDeleteAsync(cancellationToken);
}

/// <summary>
/// Recovery codes are stored and consumed by hash. There is deliberately no tracked
/// update path: spending a code is the conditional <see cref="TryConsumeAsync"/> update
/// only, which is what makes a concurrent replay of the same code impossible.
/// </summary>
public sealed class TwoFactorRecoveryCodeRepository : ITwoFactorRecoveryCodeRepository
{
    private readonly BusinessDbContext _db;

    public TwoFactorRecoveryCodeRepository(BusinessDbContext db) => _db = db;

    public Task AddRangeAsync(
        IEnumerable<TwoFactorRecoveryCode> codes,
        CancellationToken cancellationToken = default)
        => _db.TwoFactorRecoveryCodes.AddRangeAsync(codes, cancellationToken);

    public async Task<IReadOnlyList<TwoFactorRecoveryCode>> ListForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
        => await _db.TwoFactorRecoveryCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId)
            .OrderBy(c => c.CreatedAt)
            .ToListAsync(cancellationToken);

    public async Task RemoveAllForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var codes = await _db.TwoFactorRecoveryCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId)
            .ToListAsync(cancellationToken);

        _db.TwoFactorRecoveryCodes.RemoveRange(codes);
    }

    public Task<int> TryConsumeAsync(
        Guid tenantId,
        Guid userId,
        string codeHash,
        CancellationToken cancellationToken = default)
        => _db.TwoFactorRecoveryCodes
            .Where(c => c.TenantId == tenantId
                && c.UserId == userId
                && c.CodeHash == codeHash
                && c.UsedAt == null)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(c => c.UsedAt, DateTime.UtcNow),
                cancellationToken);
}

/// <summary>
/// Pending second-factor steps. Consumption is a conditional <c>UPDATE ... WHERE
/// ConsumedAt IS NULL</c> rather than a tracked read-modify-write, so two simultaneous
/// verifies of the same challenge cannot both succeed.
/// </summary>
public sealed class TwoFactorChallengeRepository : ITwoFactorChallengeRepository
{
    private readonly BusinessDbContext _db;

    public TwoFactorChallengeRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(TwoFactorChallenge challenge, CancellationToken cancellationToken = default)
        => _db.TwoFactorChallenges.AddAsync(challenge, cancellationToken).AsTask();

    public Task<TwoFactorChallenge?> GetByHashAsync(
        string tokenHash,
        CancellationToken cancellationToken = default)
        => _db.TwoFactorChallenges.FirstOrDefaultAsync(c => c.TokenHash == tokenHash, cancellationToken);

    public Task<int> TryConsumeAsync(Guid id, CancellationToken cancellationToken = default)
        => _db.TwoFactorChallenges
            .Where(c => c.Id == id && c.ConsumedAt == null && c.ExpiresAt > DateTime.UtcNow)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(c => c.ConsumedAt, DateTime.UtcNow),
                cancellationToken);

    public Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default)
        => _db.TwoFactorChallenges
            .Where(c => c.ExpiresAt < cutoff || (c.ConsumedAt != null && c.ConsumedAt < cutoff))
            .ExecuteDeleteAsync(cancellationToken);
}

public sealed class EmailVerificationCodeRepository : IEmailVerificationCodeRepository
{
    private readonly BusinessDbContext _db;

    public EmailVerificationCodeRepository(BusinessDbContext db) => _db = db;

    public Task<EmailVerificationCode?> GetByCodeHashAsync(string codeHash, CancellationToken cancellationToken = default)
        => _db.EmailVerificationCodes.FirstOrDefaultAsync(c => c.CodeHash == codeHash, cancellationToken);

    public Task<EmailVerificationCode?> GetLatestForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
        => _db.EmailVerificationCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task InvalidateAllForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var codes = await _db.EmailVerificationCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId && c.ConsumedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var code in codes)
        {
            code.TryConsume();
        }
    }

    public Task AddAsync(EmailVerificationCode code, CancellationToken cancellationToken = default)
        => _db.EmailVerificationCodes.AddAsync(code, cancellationToken).AsTask();
}

public sealed class PasswordResetCodeRepository : IPasswordResetCodeRepository
{
    private readonly BusinessDbContext _db;

    public PasswordResetCodeRepository(BusinessDbContext db) => _db = db;

    public Task<PasswordResetCode?> GetLatestForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
        => _db.PasswordResetCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task InvalidateAllForUserAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var codes = await _db.PasswordResetCodes
            .Where(c => c.TenantId == tenantId && c.UserId == userId && c.ConsumedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var code in codes)
        {
            code.TryConsume();
        }
    }

    public Task AddAsync(PasswordResetCode code, CancellationToken cancellationToken = default)
        => _db.PasswordResetCodes.AddAsync(code, cancellationToken).AsTask();
}

public sealed class InvitationCodeRepository : IInvitationCodeRepository
{
    private readonly BusinessDbContext _db;

    public InvitationCodeRepository(BusinessDbContext db) => _db = db;

    public Task<InvitationCode?> GetActiveByCodeHashAsync(
        string codeHash,
        CancellationToken cancellationToken = default)
        => _db.InvitationCodes
            .Where(c => c.CodeHash == codeHash && c.ConsumedAt == null)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<IReadOnlyList<InvitationCode>> ListActiveForTenantAsync(
        Guid tenantId,
        CancellationToken cancellationToken = default)
        => await _db.InvitationCodes
            .Where(c => c.TenantId == tenantId && c.ConsumedAt == null)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync(cancellationToken);

    public Task AddAsync(InvitationCode code, CancellationToken cancellationToken = default)
        => _db.InvitationCodes.AddAsync(code, cancellationToken).AsTask();
}

public sealed class AuditLogRepository : IAuditLogRepository
{
    private readonly BusinessDbContext _db;

    public AuditLogRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(AuditLog auditLog, CancellationToken cancellationToken = default)
        => _db.AuditLogs.AddAsync(auditLog, cancellationToken).AsTask();
}

public sealed class FeatureFlagRepository : IFeatureFlagRepository
{
    private readonly BusinessDbContext _db;

    public FeatureFlagRepository(BusinessDbContext db) => _db = db;

    public Task<FeatureFlag?> GetAsync(Guid tenantId, string key, CancellationToken cancellationToken = default)
        => _db.FeatureFlags.FirstOrDefaultAsync(f => f.TenantId == tenantId && f.Key == key, cancellationToken);

    public Task AddAsync(FeatureFlag flag, CancellationToken cancellationToken = default)
        => _db.FeatureFlags.AddAsync(flag, cancellationToken).AsTask();

    public Task UpdateAsync(FeatureFlag flag, CancellationToken cancellationToken = default)
    {
        _db.FeatureFlags.Update(flag);
        return Task.CompletedTask;
    }

    public async Task<IReadOnlyList<FeatureFlag>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.FeatureFlags
            .Where(f => f.TenantId == tenantId)
            .OrderBy(f => f.Key)
            .ToListAsync(cancellationToken);
}

public sealed class ProductRepository : IProductRepository
{
    private readonly BusinessDbContext _db;

    public ProductRepository(BusinessDbContext db) => _db = db;

    public Task<Product?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Products
            .AsSplitQuery()
            .Include(p => p.Variants)
            .FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Id == id, cancellationToken);

    public Task<Product?> GetBySkuAsync(Guid tenantId, string sku, CancellationToken cancellationToken = default)
        => _db.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Sku == sku, cancellationToken);

    public Task<Product?> GetByBarcodeAsync(Guid tenantId, string barcode, CancellationToken cancellationToken = default)
        => _db.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Barcode == barcode, cancellationToken);

    public async Task<IReadOnlyList<Product>> ListAsync(
        Guid tenantId,
        int page,
        int pageSize,
        ProductListFilter filter,
        CancellationToken cancellationToken = default)
        => await ApplyFilter(_db.Products, tenantId, filter)
            .AsNoTracking()
            .AsSplitQuery()
            .Include(p => p.Variants)
            .OrderBy(p => p.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(
        Guid tenantId,
        ProductListFilter filter,
        CancellationToken cancellationToken = default)
        => ApplyFilter(_db.Products, tenantId, filter).CountAsync(cancellationToken);

    public Task AddAsync(Product product, CancellationToken cancellationToken = default)
        => _db.Products.AddAsync(product, cancellationToken).AsTask();

    public Task<bool> VariantSkuExistsAsync(
        Guid tenantId,
        string sku,
        Guid? excludeProductId = null,
        CancellationToken cancellationToken = default)
        => _db.ProductVariants.AnyAsync(
            v => v.TenantId == tenantId && v.Sku == sku && (excludeProductId == null || v.ProductId != excludeProductId),
            cancellationToken);

    public Task<bool> VariantBarcodeExistsAsync(
        Guid tenantId,
        string barcode,
        Guid? excludeProductId = null,
        CancellationToken cancellationToken = default)
        => _db.ProductVariants.AnyAsync(
            v => v.TenantId == tenantId && v.Barcode == barcode && (excludeProductId == null || v.ProductId != excludeProductId),
            cancellationToken);

    private static IQueryable<Product> ApplyFilter(
        IQueryable<Product> query,
        Guid tenantId,
        ProductListFilter filter)
    {
        var filtered = query.Where(p => p.TenantId == tenantId);

        // The anonymous quick-sale product is a system row, never a sellable
        // catalogue item: exclude it from every product listing (M11 S3). The
        // null check keeps products without an SKU in the list (SQL NULL is not
        // equal to anything).
        filtered = filtered.Where(p =>
            p.Sku == null || p.Sku != EnsureQuickSaleProductCommandHandler.QuickSaleSku);

        if (!string.IsNullOrWhiteSpace(filter.Search))
        {
            var term = filter.Search.Trim();
            filtered = filtered.Where(p =>
                EF.Functions.ILike(p.Name, $"%{term}%")
                || (p.Sku != null && EF.Functions.ILike(p.Sku, $"%{term}%"))
                || (p.Barcode != null && EF.Functions.ILike(p.Barcode, $"%{term}%")));
        }

        if (filter.CategoryId.HasValue)
        {
            filtered = filtered.Where(p => p.CategoryId == filter.CategoryId);
        }

        if (filter.BrandId.HasValue)
        {
            filtered = filtered.Where(p => p.BrandId == filter.BrandId);
        }

        if (filter.ProductType.HasValue)
        {
            filtered = filtered.Where(p => p.ProductType == filter.ProductType.Value);
        }

        if (filter.Status.HasValue)
        {
            filtered = filtered.Where(p => p.Status == filter.Status.Value);
        }

        return filtered;
    }
}

public sealed class CategoryRepository : ICategoryRepository
{
    private readonly BusinessDbContext _db;

    public CategoryRepository(BusinessDbContext db) => _db = db;

    public Task<ProductCategory?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.ProductCategories
            .FirstOrDefaultAsync(c => c.TenantId == tenantId && c.Id == id, cancellationToken);

    public Task<ProductCategory?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.ProductCategories
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.TenantId == tenantId && c.Name == name, cancellationToken);

    public async Task<IReadOnlyList<ProductCategory>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.ProductCategories
            .AsNoTracking()
            .Where(c => c.TenantId == tenantId)
            .OrderBy(c => c.Name)
            .ToListAsync(cancellationToken);

    public Task AddAsync(ProductCategory category, CancellationToken cancellationToken = default)
        => _db.ProductCategories.AddAsync(category, cancellationToken).AsTask();

    public Task RemoveAsync(ProductCategory category, CancellationToken cancellationToken = default)
    {
        _db.ProductCategories.Remove(category);
        return Task.CompletedTask;
    }
}

public sealed class BrandRepository : IBrandRepository
{
    private readonly BusinessDbContext _db;

    public BrandRepository(BusinessDbContext db) => _db = db;

    public Task<Brand?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Brands
            .FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Id == id, cancellationToken);

    public Task<Brand?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.Brands
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Name == name, cancellationToken);

    public async Task<IReadOnlyList<Brand>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.Brands
            .AsNoTracking()
            .Where(b => b.TenantId == tenantId)
            .OrderBy(b => b.Name)
            .ToListAsync(cancellationToken);

    public Task AddAsync(Brand brand, CancellationToken cancellationToken = default)
        => _db.Brands.AddAsync(brand, cancellationToken).AsTask();

    public Task RemoveAsync(Brand brand, CancellationToken cancellationToken = default)
    {
        _db.Brands.Remove(brand);
        return Task.CompletedTask;
    }
}

public sealed class UnitOfMeasureRepository : IUnitOfMeasureRepository
{
    private readonly BusinessDbContext _db;

    public UnitOfMeasureRepository(BusinessDbContext db) => _db = db;

    public Task<UnitOfMeasure?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.UnitsOfMeasure
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.Id == id, cancellationToken);

    public Task<UnitOfMeasure?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.UnitsOfMeasure
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.Name == name, cancellationToken);

    public async Task<IReadOnlyList<UnitOfMeasure>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.UnitsOfMeasure
            .AsNoTracking()
            .Where(u => u.TenantId == tenantId)
            .OrderBy(u => u.Name)
            .ToListAsync(cancellationToken);

    public Task AddAsync(UnitOfMeasure unitOfMeasure, CancellationToken cancellationToken = default)
        => _db.UnitsOfMeasure.AddAsync(unitOfMeasure, cancellationToken).AsTask();

    public Task RemoveAsync(UnitOfMeasure unitOfMeasure, CancellationToken cancellationToken = default)
    {
        _db.UnitsOfMeasure.Remove(unitOfMeasure);
        return Task.CompletedTask;
    }
}

public sealed class WarehouseRepository : IWarehouseRepository
{
    private readonly BusinessDbContext _db;

    public WarehouseRepository(BusinessDbContext db) => _db = db;

    public Task<Warehouse?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Warehouses
            .AsSplitQuery()
            .Include(w => w.Locations)
            .FirstOrDefaultAsync(w => w.TenantId == tenantId && w.Id == id, cancellationToken);

    public Task<Warehouse?> GetByCodeAsync(Guid tenantId, string code, CancellationToken cancellationToken = default)
        => _db.Warehouses
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.TenantId == tenantId && w.Code == code, cancellationToken);

    public async Task<IReadOnlyList<Warehouse>> ListAsync(
        Guid tenantId,
        int page,
        int pageSize,
        string? search,
        Guid? branchId,
        CancellationToken cancellationToken = default)
        => await ApplyFilter(_db.Warehouses, tenantId, search, branchId)
            .AsNoTracking()
            .AsSplitQuery()
            .Include(w => w.Locations)
            .OrderBy(w => w.Code)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(
        Guid tenantId,
        string? search,
        Guid? branchId,
        CancellationToken cancellationToken = default)
        => ApplyFilter(_db.Warehouses, tenantId, search, branchId).CountAsync(cancellationToken);

    public Task AddAsync(Warehouse warehouse, CancellationToken cancellationToken = default)
        => _db.Warehouses.AddAsync(warehouse, cancellationToken).AsTask();

    private static IQueryable<Warehouse> ApplyFilter(
        IQueryable<Warehouse> query,
        Guid tenantId,
        string? search,
        Guid? branchId)
    {
        var filtered = query.Where(w => w.TenantId == tenantId);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            filtered = filtered.Where(w => w.Name.Contains(term) || w.Code.Contains(term));
        }

        if (branchId.HasValue)
        {
            filtered = filtered.Where(w => w.BranchId == branchId.Value);
        }

        return filtered;
    }
}

public sealed class StockRepository : IStockRepository
{
    private readonly BusinessDbContext _db;

    public StockRepository(BusinessDbContext db) => _db = db;

    public Task<StockBalance?> GetBalanceAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default)
        => _db.StockBalances.FirstOrDefaultAsync(
            b => b.TenantId == tenantId
                && b.WarehouseId == warehouseId
                && b.StockLocationId == stockLocationId
                && b.ProductId == productId
                && b.VariantId == variantId,
            cancellationToken);

    public Task<StockBalance?> GetBalanceWithLockAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default)
        => _db.StockBalances
            .FromSqlRaw(
                $"SELECT * FROM {Schemas.Inventory}.\"{Tables.Inventory.StockBalances}\" " +
                "WHERE \"TenantId\" = {0} AND \"WarehouseId\" = {1} AND \"StockLocationId\" = {2} " +
                "AND \"ProductId\" = {3} AND \"VariantId\" IS NOT DISTINCT FROM {4} FOR UPDATE",
                tenantId, warehouseId, stockLocationId, productId, variantId)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<StockBalance> GetOrCreateBalanceAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default)
    {
        var existing = await GetBalanceAsync(
            tenantId, warehouseId, stockLocationId, productId, variantId, cancellationToken);
        if (existing is not null)
        {
            return existing;
        }

        var created = StockBalance.Create(
            tenantId, warehouseId, stockLocationId, productId, variantId);
        _db.StockBalances.Add(created);
        return created;
    }

    public Task AddMovementAsync(StockMovement movement, CancellationToken cancellationToken = default)
        => _db.StockMovements.AddAsync(movement, cancellationToken).AsTask();

    public Task<StockMovement?> FindAdjustmentByKeyAsync(
        Guid tenantId,
        string key,
        CancellationToken cancellationToken = default)
        => _db.StockMovements.FirstOrDefaultAsync(
            m => m.TenantId == tenantId
                && m.MovementType == StockMovementType.Adjustment
                && m.CorrelationId == key,
            cancellationToken);

    public async Task<IReadOnlyList<StockBalanceView>> ListBalancesAsync(
        Guid tenantId,
        int page,
        int pageSize,
        Guid? warehouseId = null,
        Guid? productId = null,
        string? search = null,
        CancellationToken cancellationToken = default)
    {
        var rows =
            from b in _db.StockBalances
            join p in _db.Products on b.ProductId equals p.Id
            join w in _db.Warehouses on b.WarehouseId equals w.Id
            join l in _db.StockLocations on b.StockLocationId equals l.Id
            join u in _db.UnitsOfMeasure on p.UnitOfMeasureId equals u.Id
            where b.TenantId == tenantId
            select new { b, p, w, l, u };

        if (warehouseId.HasValue)
        {
            rows = rows.Where(x => x.b.WarehouseId == warehouseId.Value);
        }

        if (productId.HasValue)
        {
            rows = rows.Where(x => x.b.ProductId == productId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            rows = rows.Where(x => x.p.Name.Contains(term)
                || (x.p.Sku != null && x.p.Sku.Contains(term))
                || (x.p.Barcode != null && x.p.Barcode.Contains(term)));
        }

        var items = await rows
            .OrderBy(x => x.p.Name)
            .ThenBy(x => x.w.Name)
            .ThenBy(x => x.l.Name)
            .ThenBy(x => x.b.VariantId)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return items.Select(x => new StockBalanceView(
            x.b.WarehouseId,
            x.w.Name,
            x.b.StockLocationId,
            x.l.Name,
            x.b.ProductId,
            x.p.Name,
            x.p.Sku,
            x.p.Barcode,
            x.b.VariantId,
            x.u.Name,
            x.b.Quantity)).ToList();
    }

    public Task<int> CountBalancesAsync(
        Guid tenantId,
        Guid? warehouseId = null,
        Guid? productId = null,
        string? search = null,
        CancellationToken cancellationToken = default)
        => ApplyBalanceFilter(_db, tenantId, warehouseId, productId, search).CountAsync(cancellationToken);

    public async Task<IReadOnlyList<StockMovementView>> ListMovementsAsync(
        Guid tenantId,
        int page,
        int pageSize,
        Guid? warehouseId = null,
        Guid? productId = null,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default)
    {
        var rows =
            from m in _db.StockMovements
            join p in _db.Products on m.ProductId equals p.Id
            join w in _db.Warehouses on m.WarehouseId equals w.Id
            join l in _db.StockLocations on m.StockLocationId equals l.Id
            where m.TenantId == tenantId
            select new { m, p, w, l };

        if (warehouseId.HasValue)
        {
            rows = rows.Where(x => x.m.WarehouseId == warehouseId.Value);
        }

        if (productId.HasValue)
        {
            rows = rows.Where(x => x.m.ProductId == productId.Value);
        }

        if (type.HasValue)
        {
            rows = rows.Where(x => x.m.MovementType == type.Value);
        }

        var items = await rows
            .OrderByDescending(x => x.m.OccurredAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return items.Select(x => new StockMovementView(
            x.m.Id,
            x.m.ProductId,
            x.p.Name,
            x.p.Sku,
            x.p.Barcode,
            x.m.WarehouseId,
            x.w.Name,
            x.m.StockLocationId,
            x.l.Name,
            x.m.VariantId,
            x.m.MovementType,
            x.m.Quantity,
            x.m.Reason,
            x.m.OccurredAt,
            x.m.CreatedBy,
            x.m.CreatedAt)).ToList();
    }

    public Task<int> CountMovementsAsync(
        Guid tenantId,
        Guid? warehouseId = null,
        Guid? productId = null,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default)
        => ApplyMovementFilter(_db, tenantId, warehouseId, productId, type).CountAsync(cancellationToken);

    public async Task<IReadOnlyList<StockMovement>> ListMovementsByReferenceAsync(
        Guid tenantId,
        string referenceType,
        Guid referenceId,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default)
        => await _db.StockMovements
            .Where(m => m.TenantId == tenantId
                && m.ReferenceType == referenceType
                && m.ReferenceId == referenceId
                && (type == null || m.MovementType == type.Value))
            .AsNoTracking()
            .OrderBy(m => m.OccurredAt)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<StockSummaryRow>> GetStockSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
    {
        var balances = await _db.StockBalances
            .Where(b => b.TenantId == tenantId && (!warehouseId.HasValue || b.WarehouseId == warehouseId.Value))
            .ToListAsync(cancellationToken);

        var movements = await _db.StockMovements
            .Where(m => m.TenantId == tenantId && m.OccurredAt >= from && m.OccurredAt <= to
                && (!warehouseId.HasValue || m.WarehouseId == warehouseId.Value))
            .ToListAsync(cancellationToken);

        var productIds = balances.Select(b => b.ProductId).Distinct().ToList();
        var products = await _db.Products
            .Where(p => productIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, p => p.Name, cancellationToken);

        return balances.Select(b => {
            var productMovements = movements.Where(m => m.ProductId == b.ProductId).ToList();
            var sold = productMovements.Where(m => m.MovementType == StockMovementType.Sale).Sum(m => Math.Abs(m.Quantity));
            var purchased = productMovements.Where(m => m.MovementType == StockMovementType.TransferIn || m.MovementType == StockMovementType.OpeningStock).Sum(m => m.Quantity);
            var adjusted = productMovements.Where(m => m.MovementType == StockMovementType.Adjustment).Sum(m => m.Quantity);
            var opening = b.Quantity - purchased + sold - adjusted;

            return new StockSummaryRow(
                b.ProductId, products.GetValueOrDefault(b.ProductId, "Unknown"), null,
                Math.Max(0, opening), purchased, sold, adjusted, b.Quantity);
        }).ToList();
    }

    public async Task<IReadOnlyList<StockMovementSummaryRow>> GetStockMovementSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
    {
        return await _db.StockMovements
            .Where(m => m.TenantId == tenantId && m.OccurredAt >= from && m.OccurredAt <= to
                && (!warehouseId.HasValue || m.WarehouseId == warehouseId.Value))
            .GroupBy(m => m.MovementType.ToString())
            .Select(g => new StockMovementSummaryRow(
                g.Key, g.Count(), g.Sum(m => Math.Abs(m.Quantity))))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<LowStockReportItem>> GetLowStockReportAsync(
        Guid tenantId, decimal threshold, Guid? warehouseId, CancellationToken cancellationToken = default)
    {
        var balances = await _db.StockBalances
            .Where(b => b.TenantId == tenantId && b.Quantity <= threshold && b.Quantity >= 0
                && (!warehouseId.HasValue || b.WarehouseId == warehouseId.Value))
            .ToListAsync(cancellationToken);

        var productIds = balances.Select(b => b.ProductId).Distinct().ToList();
        var warehouseIds = balances.Select(b => b.WarehouseId).Distinct().ToList();
        var products = await _db.Products
            .Where(p => productIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, p => p.Name, cancellationToken);
        var warehouses = await _db.Warehouses
            .Where(w => warehouseIds.Contains(w.Id))
            .ToDictionaryAsync(w => w.Id, w => w.Name, cancellationToken);

        return balances
            .Select(b => new LowStockReportItem(
                b.ProductId, products.GetValueOrDefault(b.ProductId, "Unknown"), null,
                b.Quantity, warehouses.GetValueOrDefault(b.WarehouseId, "Unknown")))
            .OrderBy(x => x.OnHand)
            .ToList();
    }

    public async Task<IReadOnlyList<StockVelocityRow>> GetStockVelocityAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        var days = Math.Max(1, (to - from).Days);
        var sales = await _db.Sales
            .Where(s => s.TenantId == tenantId && s.SaleDate >= from && s.SaleDate <= to && s.Status != SaleStatus.Voided)
            .SelectMany(s => s.Lines)
            .GroupBy(l => l.ProductId)
            .Select(g => new
            {
                ProductId = g.Key,
                ProductName = g.First().ProductName,
                Sku = g.First().Sku,
                Sold = g.Sum(l => l.Quantity),
            })
            .OrderByDescending(x => x.Sold)
            .ToListAsync(cancellationToken);

        var productIds = sales.Select(s => s.ProductId).ToList();
        var balances = await _db.StockBalances
            .Where(b => b.TenantId == tenantId && productIds.Contains(b.ProductId))
            .ToDictionaryAsync(b => b.ProductId, b => b.Quantity, cancellationToken);

        return sales.Select(s => new StockVelocityRow(
            s.ProductId, s.ProductName, s.Sku,
            s.Sold, balances.GetValueOrDefault(s.ProductId, 0),
            Math.Round(s.Sold / days, 2))).ToList();
    }

    private static IQueryable<StockBalance> ApplyBalanceFilter(
        BusinessDbContext db,
        Guid tenantId,
        Guid? warehouseId,
        Guid? productId,
        string? search)
    {
        var query = db.StockBalances.Where(b => b.TenantId == tenantId);

        if (warehouseId.HasValue)
        {
            query = query.Where(b => b.WarehouseId == warehouseId.Value);
        }

        if (productId.HasValue)
        {
            query = query.Where(b => b.ProductId == productId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Join(
                    db.Products.Where(p => p.TenantId == tenantId),
                    b => b.ProductId,
                    p => p.Id,
                    (b, p) => new { b, p })
                .Where(x => x.p.Name.Contains(term)
                    || (x.p.Sku != null && x.p.Sku.Contains(term))
                    || (x.p.Barcode != null && x.p.Barcode.Contains(term)))
                .Select(x => x.b);
        }

        return query;
    }

    private static IQueryable<StockMovement> ApplyMovementFilter(
        BusinessDbContext db,
        Guid tenantId,
        Guid? warehouseId,
        Guid? productId,
        StockMovementType? type)
    {
        var query = db.StockMovements.Where(m => m.TenantId == tenantId);

        if (warehouseId.HasValue)
        {
            query = query.Where(m => m.WarehouseId == warehouseId.Value);
        }

        if (productId.HasValue)
        {
            query = query.Where(m => m.ProductId == productId.Value);
        }

        if (type.HasValue)
        {
            query = query.Where(m => m.MovementType == type.Value);
        }

        return query;
    }
}

public sealed class PriceListRepository : IPriceListRepository
{
    private readonly BusinessDbContext _db;

    public PriceListRepository(BusinessDbContext db) => _db = db;

    public Task<PriceList?> GetByIdAsync(
        Guid tenantId,
        Guid id,
        bool includePrices = false,
        CancellationToken cancellationToken = default)
    {
        var query = _db.PriceLists.Where(p => p.TenantId == tenantId && p.Id == id);
        if (includePrices)
        {
            query = query.AsSplitQuery().Include(p => p.Prices);
        }

        return query.FirstOrDefaultAsync(cancellationToken);
    }

    public Task<PriceList?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.PriceLists
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Name == name, cancellationToken);

    public Task<PriceList?> GetDefaultAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.PriceLists
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.TenantId == tenantId && p.IsDefault, cancellationToken);

    public async Task<IReadOnlyList<PriceList>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.PriceLists
            .AsNoTracking()
            .Where(p => p.TenantId == tenantId)
            .OrderBy(p => p.Name)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<ProductPrice>> ResolvePricesAsync(
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate,
        CancellationToken cancellationToken = default)
        => await ProductPriceRepository.ApplyResolveFilter(
                _db.ProductPrices,
                tenantId,
                priceListId,
                productId,
                variantId,
                branchId,
                priceType,
                quantity,
                onDate)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

    public Task AddAsync(PriceList priceList, CancellationToken cancellationToken = default)
        => _db.PriceLists.AddAsync(priceList, cancellationToken).AsTask();
}

public sealed class ProductPriceRepository : IProductPriceRepository
{
    private readonly BusinessDbContext _db;

    public ProductPriceRepository(BusinessDbContext db) => _db = db;

    public async Task<IReadOnlyList<ProductPrice>> ListAsync(
        Guid tenantId,
        Guid priceListId,
        Guid? productId = null,
        Guid? branchId = null,
        PriceType? priceType = null,
        CancellationToken cancellationToken = default)
        => await ApplyListFilter(_db.ProductPrices, tenantId, priceListId, productId, branchId, priceType)
            .AsNoTracking()
            .OrderBy(p => p.ProductId)
            .ThenBy(p => p.VariantId)
            .ThenBy(p => p.BranchId)
            .ThenBy(p => p.PriceType)
            .ToListAsync(cancellationToken);

    public Task UpsertManyAsync(
        PriceList priceList, IEnumerable<ProductPriceSpec> prices, CancellationToken cancellationToken = default)
    {
        priceList.SetPrices(prices);
        return Task.CompletedTask;
    }

    public async Task<IReadOnlyList<ProductPrice>> ResolveAsync(
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate,
        CancellationToken cancellationToken = default)
        => await ApplyResolveFilter(
                _db.ProductPrices,
                tenantId,
                priceListId,
                productId,
                variantId,
                branchId,
                priceType,
                quantity,
                onDate)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

    internal static IQueryable<ProductPrice> ApplyResolveFilter(
        IQueryable<ProductPrice> query,
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate)
        => query
            .Where(p => p.TenantId == tenantId)
            .Where(p => p.PriceListId == priceListId)
            .Where(p => p.ProductId == productId)
            .Where(p => p.VariantId == variantId)
            .Where(p => p.PriceType == priceType)
            .Where(p => p.MinQuantity <= quantity)
            .Where(p => p.IsActive)
            .Where(p => p.EffectiveFrom == null || p.EffectiveFrom <= onDate)
            .Where(p => p.EffectiveTo == null || p.EffectiveTo >= onDate)
            .Where(p => branchId.HasValue
                ? p.BranchId == null || p.BranchId == branchId
                : p.BranchId == null);

    private static IQueryable<ProductPrice> ApplyListFilter(
        IQueryable<ProductPrice> query,
        Guid tenantId,
        Guid priceListId,
        Guid? productId,
        Guid? branchId,
        PriceType? priceType)
    {
        var filtered = query.Where(p => p.TenantId == tenantId && p.PriceListId == priceListId);

        if (productId.HasValue)
        {
            filtered = filtered.Where(p => p.ProductId == productId.Value);
        }

        if (branchId.HasValue)
        {
            filtered = filtered.Where(p => p.BranchId == branchId.Value);
        }

        if (priceType.HasValue)
        {
            filtered = filtered.Where(p => p.PriceType == priceType.Value);
        }

        return filtered;
    }
}

public sealed class DashboardRepository : IDashboardRepository
{
    private readonly BusinessDbContext _db;

    public DashboardRepository(BusinessDbContext db) => _db = db;

    public async Task<DashboardSnapshot> GetSummaryAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
    {
        var statusCounts = await _db.Products
            .Where(p => p.TenantId == tenantId)
            .GroupBy(p => p.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync(cancellationToken);

        var totalProducts = statusCounts.Sum(x => x.Count);
        var activeProducts = statusCounts.FirstOrDefault(x => x.Status == ProductStatus.Active)?.Count ?? 0;
        var draftProducts = statusCounts.FirstOrDefault(x => x.Status == ProductStatus.Draft)?.Count ?? 0;
        var inactiveProducts = statusCounts.FirstOrDefault(x => x.Status == ProductStatus.Inactive)?.Count ?? 0;

        var serviceProducts = await _db.Products
            .CountAsync(p => p.TenantId == tenantId && p.ProductType == ProductType.Service, cancellationToken);
        var totalVariants = await _db.ProductVariants
            .CountAsync(v => v.TenantId == tenantId, cancellationToken);
        var totalCategories = await _db.ProductCategories
            .CountAsync(c => c.TenantId == tenantId, cancellationToken);

        var catalog = new DashboardCatalogSnapshot(
            totalProducts, activeProducts, draftProducts, inactiveProducts,
            serviceProducts, totalVariants, totalCategories);

        var totalWarehouses = await _db.Warehouses
            .CountAsync(w => w.TenantId == tenantId, cancellationToken);
        var totalStockLines = await _db.StockBalances
            .CountAsync(b => b.TenantId == tenantId, cancellationToken);
        var totalOnHandUnits = await _db.StockBalances
            .Where(b => b.TenantId == tenantId)
            .SumAsync(b => (decimal?)b.Quantity, cancellationToken) ?? 0m;

        var productTotals = await _db.StockBalances
            .Where(b => b.TenantId == tenantId)
            .GroupBy(b => b.ProductId)
            .Select(g => new { ProductId = g.Key, Total = g.Sum(b => b.Quantity) })
            .ToListAsync(cancellationToken);

        var stockedProducts = productTotals.Count(x => x.Total > 0);
        var zeroStockLines = await _db.StockBalances
            .CountAsync(b => b.TenantId == tenantId && b.Quantity <= 0, cancellationToken);
        var totalMovements = await _db.StockMovements
            .CountAsync(m => m.TenantId == tenantId, cancellationToken);

        var inventory = new DashboardInventorySnapshot(
            totalWarehouses, totalStockLines, totalOnHandUnits, stockedProducts, zeroStockLines, totalMovements);

        var priceLists = await _db.PriceLists
            .Where(pl => pl.TenantId == tenantId)
            .ToListAsync(cancellationToken);

        var pricing = await BuildPricingSnapshotAsync(tenantId, priceLists, cancellationToken);

        var totalBranches = await _db.Branches
            .CountAsync(b => b.TenantId == tenantId, cancellationToken);
        var totalUsers = await _db.Users
            .CountAsync(u => u.TenantId == tenantId, cancellationToken);
        var activeUsers = await _db.Users
            .CountAsync(u => u.TenantId == tenantId && u.IsActive, cancellationToken);
        var totalRoles = await _db.Roles
            .CountAsync(r => r.TenantId == tenantId, cancellationToken);

        var organization = new DashboardOrganizationSnapshot(
            totalBranches, totalUsers, activeUsers, totalRoles);

        return new DashboardSnapshot(catalog, inventory, pricing, organization);
    }

    public async Task<IReadOnlyList<LowStockItem>> ListLowStockAsync(
        Guid tenantId, decimal maxQuantity, int limit, CancellationToken cancellationToken = default)
    {
        var totals = await _db.StockBalances
            .Where(b => b.TenantId == tenantId)
            .GroupBy(b => b.ProductId)
            .Select(g => new { ProductId = g.Key, Total = g.Sum(b => b.Quantity) })
            .Where(x => x.Total <= maxQuantity)
            .OrderBy(x => x.Total)
            .Take(limit)
            .ToListAsync(cancellationToken);

        if (totals.Count == 0)
        {
            return Array.Empty<LowStockItem>();
        }

        var productIds = totals.Select(x => x.ProductId).ToArray();
        var products = await _db.Products
            .Where(p => productIds.Contains(p.Id))
            .Select(p => new { p.Id, p.Name, p.Sku })
            .ToDictionaryAsync(p => p.Id, cancellationToken);

        return totals
            .Where(x => products.ContainsKey(x.ProductId))
            .Select(x => new LowStockItem(
                x.ProductId,
                products[x.ProductId].Name,
                products[x.ProductId].Sku,
                x.Total))
            .ToList();
    }

    public async Task<IReadOnlyList<RecentActivityItem>> ListRecentActivityAsync(
        Guid tenantId, int limit, CancellationToken cancellationToken = default)
    {
        var meaningfulTypes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "Sale", "Product", "Customer", "Expense", "Purchase", "StockMovement", "User", "PriceList",

            // Generic audit rows written by AuditBehavior for every mutation command.
            "Command"
        };

        var logs = await _db.AuditLogs
            .Where(a => a.TenantId == tenantId && meaningfulTypes.Contains(a.EntityType))
            .OrderByDescending(a => a.CreatedAt)
            .ThenByDescending(a => a.Id)
            .Take(limit)
            .ToListAsync(cancellationToken);

        if (logs.Count == 0)
        {
            return Array.Empty<RecentActivityItem>();
        }

        var actorIds = logs.Where(l => l.UserId.HasValue).Select(l => l.UserId!.Value).Distinct().ToArray();
        var actors = await _db.Users
            .Where(u => actorIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, cancellationToken);

        var entityLookups = await BuildEntityLookupsAsync(tenantId, logs, cancellationToken);

        return logs
            .Select(l =>
            {
                var lookup = entityLookups.TryGetValue((l.EntityType, l.EntityId ?? string.Empty), out var found)
                    ? found : default;
                return new RecentActivityItem(
                    l.Action,
                    l.EntityType,
                    l.EntityId,
                    lookup.Name,
                    lookup.Amount,
                    lookup.Status,
                    l.UserId.HasValue && actors.ContainsKey(l.UserId.Value) ? actors[l.UserId.Value].Email : null,
                    l.CreatedAt);
            })
            .ToList();
    }

    private async Task<Dictionary<(string, string), (string? Name, decimal? Amount, string? Status)>>
        BuildEntityLookupsAsync(
            Guid tenantId,
            List<Domain.Audit.AuditLog> logs,
            CancellationToken cancellationToken)
    {
        var result = new Dictionary<(string, string), (string?, decimal?, string?)>();

        var saleIds = logs
            .Where(l => l.EntityType.Equals("Sale", StringComparison.OrdinalIgnoreCase) && l.EntityId != null)
            .Select(l => l.EntityId!)
            .ToList();
        if (saleIds.Count > 0)
        {
            var parsed = saleIds.Where(s => Guid.TryParse(s, out _)).Select(s => Guid.Parse(s)).ToList();
            var sales = await _db.Sales
                .Where(s => s.TenantId == tenantId && parsed.Contains(s.Id))
                .ToDictionaryAsync(s => s.Id, cancellationToken);
            foreach (var sid in parsed)
            {
                if (sales.TryGetValue(sid, out var sale))
                {
                    var status = sale.Status == Domain.Sales.SaleStatus.Voided ? "Voided" : sale.AmountPaid >= sale.TotalAmount ? "Paid" : "Pending";
                    result[("Sale", sid.ToString())] = ($"Risiti #{sale.Number}", sale.TotalAmount, status);
                }
            }
        }

        var productIds = logs
            .Where(l => l.EntityType.Equals("Product", StringComparison.OrdinalIgnoreCase) && l.EntityId != null)
            .Select(l => l.EntityId!)
            .ToList();
        if (productIds.Count > 0)
        {
            var parsed = productIds.Where(s => Guid.TryParse(s, out _)).Select(s => Guid.Parse(s)).ToList();
            var products = await _db.Products
                .Where(p => p.TenantId == tenantId && parsed.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, cancellationToken);
            foreach (var pid in parsed)
            {
                if (products.TryGetValue(pid, out var product))
                    result[("Product", pid.ToString())] = (product.Name, null, null);
            }
        }

        var customerIds = logs
            .Where(l => l.EntityType.Equals("Customer", StringComparison.OrdinalIgnoreCase) && l.EntityId != null)
            .Select(l => l.EntityId!)
            .ToList();
        if (customerIds.Count > 0)
        {
            var parsed = customerIds.Where(s => Guid.TryParse(s, out _)).Select(s => Guid.Parse(s)).ToList();
            var customers = await _db.Customers
                .Where(c => c.TenantId == tenantId && parsed.Contains(c.Id))
                .ToDictionaryAsync(c => c.Id, cancellationToken);
            foreach (var cid in parsed)
            {
                if (customers.TryGetValue(cid, out var customer))
                    result[("Customer", cid.ToString())] = (customer.Name, null, null);
            }
        }

        var expenseIds = logs
            .Where(l => l.EntityType.Equals("Expense", StringComparison.OrdinalIgnoreCase) && l.EntityId != null)
            .Select(l => l.EntityId!)
            .ToList();
        if (expenseIds.Count > 0)
        {
            var parsed = expenseIds.Where(s => Guid.TryParse(s, out _)).Select(s => Guid.Parse(s)).ToList();
            var expenses = await _db.Expenses
                .Where(e => e.TenantId == tenantId && parsed.Contains(e.Id))
                .ToDictionaryAsync(e => e.Id, cancellationToken);
            foreach (var eid in parsed)
            {
                if (expenses.TryGetValue(eid, out var expense))
                    result[("Expense", eid.ToString())] = (expense.Description ?? "Gharama", expense.Amount, null);
            }
        }

        var purchaseIds = logs
            .Where(l => l.EntityType.Equals("Purchase", StringComparison.OrdinalIgnoreCase) && l.EntityId != null)
            .Select(l => l.EntityId!)
            .ToList();
        if (purchaseIds.Count > 0)
        {
            var parsed = purchaseIds.Where(s => Guid.TryParse(s, out _)).Select(s => Guid.Parse(s)).ToList();
            var purchases = await _db.PurchaseOrders
                .Where(p => p.TenantId == tenantId && parsed.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, cancellationToken);
            foreach (var pid in parsed)
            {
                if (purchases.TryGetValue(pid, out var purchase))
                    result[("Purchase", pid.ToString())] = (purchase.Reference ?? $"Ununuzi", purchase.TotalAmount, null);
            }
        }

        return result;
    }

    private async Task<DashboardPricingSnapshot> BuildPricingSnapshotAsync(
        Guid tenantId, IReadOnlyList<PriceList> priceLists, CancellationToken cancellationToken)
    {
        var defaultList = priceLists.FirstOrDefault(pl => pl.IsDefault);

        if (defaultList is null)
        {
            return new DashboardPricingSnapshot(priceLists.Count, null, 0, 0);
        }

        var today = DateTime.UtcNow.Date;
        var prices = await _db.ProductPrices
            .Where(p => p.TenantId == tenantId
                && p.PriceListId == defaultList.Id
                && p.IsActive
                && (p.EffectiveFrom == null || p.EffectiveFrom <= today)
                && (p.EffectiveTo == null || p.EffectiveTo >= today))
            .Select(p => new { p.ProductId, p.BranchId })
            .ToListAsync(cancellationToken);

        return new DashboardPricingSnapshot(
            priceLists.Count,
            defaultList.Name,
            prices.Select(x => x.ProductId).Distinct().Count(),
            prices.Where(x => x.BranchId != null).Select(x => x.ProductId).Distinct().Count());
    }
}

public sealed class TaxRuleRepository : ITaxRuleRepository
{
    private readonly BusinessDbContext _db;

    public TaxRuleRepository(BusinessDbContext db) => _db = db;

    public async Task<TaxRegime?> GetRegimeForTenantAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
    {
        var countryCode = await _db.Tenants
            .AsNoTracking()
            .Where(t => t.Id == tenantId)
            .Select(t => t.CountryCode)
            .FirstOrDefaultAsync(cancellationToken);

        return countryCode is null
            ? null
            : await _db.TaxRegimes
                .AsNoTracking()
                .FirstOrDefaultAsync(r => r.CountryCode == countryCode, cancellationToken);
    }

    public Task<TaxCategory?> GetCategoryByIdAsync(
        Guid id, CancellationToken cancellationToken = default)
        => _db.TaxCategories
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);

    public async Task<IReadOnlyList<TaxCategory>> ListCategoriesAsync(
        CancellationToken cancellationToken = default)
        => await _db.TaxCategories
            .AsNoTracking()
            .OrderBy(c => c.Code)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<TaxCategory>> ListCategoriesByCodesAsync(
        IEnumerable<string> codes, CancellationToken cancellationToken = default)
    {
        var codeList = codes.Select(c => c.Trim().ToUpperInvariant()).Distinct().ToArray();
        if (codeList.Length == 0)
        {
            return Array.Empty<TaxCategory>();
        }

        return await _db.TaxCategories
            .AsNoTracking()
            .Where(c => codeList.Contains(c.Code))
            .OrderBy(c => c.Code)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<TaxRule>> ListEffectiveRulesAsync(
        Guid regimeId, DateTime onDate, CancellationToken cancellationToken = default)
        => await _db.TaxRules
            .AsNoTracking()
            .Where(r => r.RegimeId == regimeId
                && (r.EffectiveFrom == null || r.EffectiveFrom <= onDate)
                && (r.EffectiveTo == null || r.EffectiveTo >= onDate))
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<TaxExemption>> ListExemptionsAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.TaxExemptions
            .AsNoTracking()
            .Where(e => e.TenantId == tenantId)
            .ToListAsync(cancellationToken);
}

public sealed class SaleRepository : ISaleRepository
{
    private readonly BusinessDbContext _db;

    public SaleRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Sale sale, CancellationToken cancellationToken = default)
        => _db.Sales.AddAsync(sale, cancellationToken).AsTask();

    public Task UpdateAsync(Sale sale, CancellationToken cancellationToken = default)
    {
        _db.Sales.Update(sale);
        return Task.CompletedTask;
    }

    public async Task<Sale?> GetByIdAsync(
        Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => await _db.Sales
            .AsNoTracking()
            .AsSplitQuery()
            .Include(s => s.Lines)
            .Include(s => s.Payments)
            .FirstOrDefaultAsync(s => s.TenantId == tenantId && s.Id == id, cancellationToken);

    public async Task<Sale?> GetByClientSaleIdAsync(
        Guid tenantId, Guid clientSaleId, CancellationToken cancellationToken = default)
        => await _db.Sales
            .AsNoTracking()
            .AsSplitQuery()
            .Include(s => s.Lines)
            .Include(s => s.Payments)
            .FirstOrDefaultAsync(s => s.TenantId == tenantId && s.ClientSaleId == clientSaleId, cancellationToken);

    public async Task<IReadOnlyList<Sale>> ListAsync(
        Guid tenantId, int page, int pageSize, SaleListFilter filter, CancellationToken cancellationToken = default)
        => await _db.Sales
            .AsNoTracking()
            .AsSplitQuery()
            .Include(s => s.Lines)
            .Include(s => s.Payments)
            .Where(ApplyFilter(tenantId, filter))
            .OrderByDescending(s => s.SaleDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, SaleListFilter filter, CancellationToken cancellationToken = default)
        => _db.Sales
            .AsNoTracking()
            .Where(ApplyFilter(tenantId, filter))
            .CountAsync(cancellationToken);

    private static System.Linq.Expressions.Expression<Func<Sale, bool>> ApplyFilter(
        Guid tenantId, SaleListFilter filter)
    {
        return s => s.TenantId == tenantId
            && (!filter.BranchId.HasValue || s.BranchId == filter.BranchId.Value)
            && (!filter.FromDate.HasValue || s.SaleDate >= filter.FromDate.Value)
            && (!filter.ToDate.HasValue || s.SaleDate < filter.ToDate.Value.AddDays(1))
            && (!filter.Status.HasValue || s.Status == filter.Status.Value)
            && (string.IsNullOrWhiteSpace(filter.Search)
                || s.Number.Contains(filter.Search.Trim())
                || (s.CustomerName != null && s.CustomerName.Contains(filter.Search.Trim())));
    }
}

public sealed class NumberSequenceRepository : INumberSequenceRepository
{
    private readonly BusinessDbContext _db;

    public NumberSequenceRepository(BusinessDbContext db) => _db = db;

    public async Task<string> AllocateAsync(
        Guid tenantId, string scope, DateTime date, CancellationToken cancellationToken = default)
    {
        var sequence = await _db.NumberSequences
            .FromSqlRaw(
                $"SELECT * FROM {Schemas.Sales}.\"{Tables.Sales.NumberSequences}\" " +
                "WHERE \"TenantId\" = {0} AND \"Scope\" = {1} FOR UPDATE",
                tenantId, scope)
            .FirstOrDefaultAsync(cancellationToken);

        if (sequence is null)
        {
            // "Sale" keeps the POS receipt format; every other scope gets its own
            // dedicated prefix (e.g. scope "Invoice" → prefix "INV", scope
            // "CustomerInvoice" → prefix "CINV").
            var prefix = scope switch
            {
                "Sale" => null,
                "CustomerInvoice" => "CINV",
                _ => scope[..Math.Min(3, scope.Length)],
            };

            sequence = prefix is null
                ? NumberSequence.CreateSaleSequence(tenantId)
                : NumberSequence.Create(tenantId, scope, prefix, "{prefix}-{year}-{sequence:000000}");
            _db.NumberSequences.Add(sequence);
        }

        return sequence.Allocate(date);
    }
}

public sealed class TransferRepository : ITransferRepository
{
    private readonly BusinessDbContext _db;

    public TransferRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Transfer transfer, CancellationToken cancellationToken = default)
        => _db.Transfers.AddAsync(transfer, cancellationToken).AsTask();

    public Task UpdateAsync(Transfer transfer, CancellationToken cancellationToken = default)
    {
        _db.Transfers.Update(transfer);
        return Task.CompletedTask;
    }

    public Task<Transfer?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Transfers
            .Include(t => t.Lines)
            .FirstOrDefaultAsync(t => t.TenantId == tenantId && t.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Transfer>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.Transfers
            .Where(t => t.TenantId == tenantId)
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.Transfers.CountAsync(t => t.TenantId == tenantId, cancellationToken);
}

public sealed class StockCountRepository : IStockCountRepository
{
    private readonly BusinessDbContext _db;

    public StockCountRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(StockCount count, CancellationToken cancellationToken = default)
        => _db.StockCounts.AddAsync(count, cancellationToken).AsTask();

    public Task UpdateAsync(StockCount count, CancellationToken cancellationToken = default)
    {
        _db.StockCounts.Update(count);
        return Task.CompletedTask;
    }

    public Task<StockCount?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.StockCounts
            .FirstOrDefaultAsync(c => c.TenantId == tenantId && c.Id == id, cancellationToken);

    public async Task<IReadOnlyList<StockCount>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.StockCounts
            .Where(c => c.TenantId == tenantId)
            .OrderByDescending(c => c.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.StockCounts.CountAsync(c => c.TenantId == tenantId, cancellationToken);
}

public sealed class StockBatchRepository : IStockBatchRepository
{
    private readonly BusinessDbContext _db;

    public StockBatchRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(StockBatch batch, CancellationToken cancellationToken = default)
        => _db.StockBatches.AddAsync(batch, cancellationToken).AsTask();

    public Task UpdateAsync(StockBatch batch, CancellationToken cancellationToken = default)
    {
        _db.StockBatches.Update(batch);
        return Task.CompletedTask;
    }

    public Task<StockBatch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.StockBatches
            .FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Id == id, cancellationToken);

    public Task<StockBatch?> GetByBatchNumberAsync(Guid tenantId, Guid productId, string batchNumber, CancellationToken cancellationToken = default)
        => _db.StockBatches
            .FirstOrDefaultAsync(b => b.TenantId == tenantId && b.ProductId == productId && b.BatchNumber == batchNumber, cancellationToken);

    public async Task<IReadOnlyList<StockBatch>> ListAsync(Guid tenantId, int page, int pageSize, Guid? productId = null, CancellationToken cancellationToken = default)
    {
        IQueryable<StockBatch> query = _db.StockBatches.Where(b => b.TenantId == tenantId);
        if (productId.HasValue)
            query = query.Where(b => b.ProductId == productId.Value);
        return await query
            .OrderByDescending(b => b.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountAsync(Guid tenantId, Guid? productId = null, CancellationToken cancellationToken = default)
    {
        IQueryable<StockBatch> query = _db.StockBatches.Where(b => b.TenantId == tenantId);
        if (productId.HasValue)
            query = query.Where(b => b.ProductId == productId.Value);
        return query.CountAsync(cancellationToken);
    }
}

public sealed class SupplierRepository : ISupplierRepository
{
    private readonly BusinessDbContext _db;

    public SupplierRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Supplier supplier, CancellationToken cancellationToken = default)
        => _db.Suppliers.AddAsync(supplier, cancellationToken).AsTask();

    public Task UpdateAsync(Supplier supplier, CancellationToken cancellationToken = default)
    {
        _db.Suppliers.Update(supplier);
        return Task.CompletedTask;
    }

    public Task<Supplier?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Suppliers.FirstOrDefaultAsync(s => s.TenantId == tenantId && s.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Supplier>> ListAsync(Guid tenantId, int page, int pageSize, string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Supplier> query = _db.Suppliers.Where(s => s.TenantId == tenantId);
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(s => s.Name.Contains(search.Trim()));
        return await query
            .OrderBy(s => s.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountAsync(Guid tenantId, string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Supplier> query = _db.Suppliers.Where(s => s.TenantId == tenantId);
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(s => s.Name.Contains(search.Trim()));
        return query.CountAsync(cancellationToken);
    }
}

public sealed class PurchaseOrderRepository : IPurchaseOrderRepository
{
    private readonly BusinessDbContext _db;

    public PurchaseOrderRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(PurchaseOrder order, CancellationToken cancellationToken = default)
        => _db.PurchaseOrders.AddAsync(order, cancellationToken).AsTask();

    public Task UpdateAsync(PurchaseOrder order, CancellationToken cancellationToken = default)
    {
        _db.PurchaseOrders.Update(order);
        return Task.CompletedTask;
    }

    public Task<PurchaseOrder?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.PurchaseOrders
            .Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.TenantId == tenantId && o.Id == id, cancellationToken);

    public async Task<IReadOnlyList<PurchaseOrder>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.PurchaseOrders
            .Where(o => o.TenantId == tenantId)
            .OrderByDescending(o => o.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.PurchaseOrders.CountAsync(o => o.TenantId == tenantId, cancellationToken);
}

public sealed class SupplierBillRepository : ISupplierBillRepository
{
    private readonly BusinessDbContext _db;

    public SupplierBillRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(SupplierBill bill, CancellationToken cancellationToken = default)
        => _db.SupplierBills.AddAsync(bill, cancellationToken).AsTask();

    public Task UpdateAsync(SupplierBill bill, CancellationToken cancellationToken = default)
    {
        _db.SupplierBills.Update(bill);
        return Task.CompletedTask;
    }

    public Task<SupplierBill?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.SupplierBills.FirstOrDefaultAsync(b => b.TenantId == tenantId && b.Id == id, cancellationToken);

    public Task<SupplierBill?> GetByPurchaseOrderAsync(Guid tenantId, Guid purchaseOrderId, CancellationToken cancellationToken = default)
        => _db.SupplierBills.FirstOrDefaultAsync(b => b.TenantId == tenantId && b.PurchaseOrderId == purchaseOrderId, cancellationToken);

    public async Task<IReadOnlyList<SupplierBill>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.SupplierBills
            .Where(b => b.TenantId == tenantId)
            .OrderByDescending(b => b.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.SupplierBills.CountAsync(b => b.TenantId == tenantId, cancellationToken);
}

public sealed class SupplierPaymentRepository : ISupplierPaymentRepository
{
    private readonly BusinessDbContext _db;

    public SupplierPaymentRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(SupplierPayment payment, CancellationToken cancellationToken = default)
        => _db.SupplierPayments.AddAsync(payment, cancellationToken).AsTask();

    public async Task<IReadOnlyList<SupplierBill>> ListByBillAsync(Guid tenantId, Guid supplierBillId, CancellationToken cancellationToken = default)
        => await _db.SupplierBills
            .Where(b => b.TenantId == tenantId && b.Id == supplierBillId)
            .ToListAsync(cancellationToken);
}

public sealed class AccountRepository : IAccountRepository
{
    private readonly BusinessDbContext _db;

    public AccountRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Account account, CancellationToken cancellationToken = default)
        => _db.Accounts.AddAsync(account, cancellationToken).AsTask();

    public Task UpdateAsync(Account account, CancellationToken cancellationToken = default)
    {
        _db.Accounts.Update(account);
        return Task.CompletedTask;
    }

    public Task<Account?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Accounts.FirstOrDefaultAsync(a => a.TenantId == tenantId && a.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Account>> ListAsync(Guid tenantId, bool? isActive = null, CancellationToken cancellationToken = default)
        => await _db.Accounts
            .Where(a => a.TenantId == tenantId && (isActive == null || a.IsActive == isActive))
            .OrderBy(a => a.Code)
            .ToListAsync(cancellationToken);
}

public sealed class JournalEntryRepository : IJournalEntryRepository
{
    private readonly BusinessDbContext _db;

    public JournalEntryRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(JournalEntry entry, CancellationToken cancellationToken = default)
        => _db.JournalEntries.AddAsync(entry, cancellationToken).AsTask();

    public Task UpdateAsync(JournalEntry entry, CancellationToken cancellationToken = default)
    {
        _db.JournalEntries.Update(entry);
        return Task.CompletedTask;
    }

    public Task<JournalEntry?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.JournalEntries
            .Include(j => j.Lines)
            .FirstOrDefaultAsync(j => j.TenantId == tenantId && j.Id == id, cancellationToken);

    public Task<JournalEntry?> GetBySourceAsync(Guid tenantId, string sourceType, Guid sourceId, CancellationToken cancellationToken = default)
        => _db.JournalEntries
            .Include(j => j.Lines)
            .FirstOrDefaultAsync(j => j.TenantId == tenantId && j.SourceType == sourceType && j.SourceId == sourceId, cancellationToken);

    public async Task<IReadOnlyList<JournalEntry>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.JournalEntries
            .Include(j => j.Lines)
            .Where(j => j.TenantId == tenantId)
            .OrderByDescending(j => j.EntryDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.JournalEntries.CountAsync(j => j.TenantId == tenantId, cancellationToken);
}

public sealed class TenantAccountMappingRepository : ITenantAccountMappingRepository
{
    private readonly BusinessDbContext _db;

    public TenantAccountMappingRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(TenantAccountMapping mapping, CancellationToken cancellationToken = default)
        => _db.TenantAccountMappings.AddAsync(mapping, cancellationToken).AsTask();

    public Task<TenantAccountMapping?> GetByMappingKeyAsync(Guid tenantId, string mappingKey, CancellationToken cancellationToken = default)
        => _db.TenantAccountMappings.FirstOrDefaultAsync(m => m.TenantId == tenantId && m.MappingKey == mappingKey, cancellationToken);
}

public sealed class ExpenseRepository : IExpenseRepository
{
    private readonly BusinessDbContext _db;

    public ExpenseRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Expense expense, CancellationToken cancellationToken = default)
        => _db.Expenses.AddAsync(expense, cancellationToken).AsTask();

    public Task UpdateAsync(Expense expense, CancellationToken cancellationToken = default)
    {
        _db.Expenses.Update(expense);
        return Task.CompletedTask;
    }

    public Task RemoveAsync(Expense expense, CancellationToken cancellationToken = default)
    {
        _db.Expenses.Remove(expense);
        return Task.CompletedTask;
    }

    public Task<Expense?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Expenses.FirstOrDefaultAsync(e => e.TenantId == tenantId && e.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Expense>> ListAsync(
        Guid tenantId, int page, int pageSize,
        DateTime? fromDate = null, DateTime? toDate = null,
        string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Expense> query = _db.Expenses.Where(e => e.TenantId == tenantId);

        if (fromDate.HasValue)
            query = query.Where(e => e.ExpenseDate >= fromDate.Value);
        if (toDate.HasValue)
            query = query.Where(e => e.ExpenseDate <= toDate.Value);
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(e => e.Description.Contains(search));

        return await query
            .OrderByDescending(e => e.ExpenseDate)
            .ThenByDescending(e => e.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountAsync(
        Guid tenantId, DateTime? fromDate = null, DateTime? toDate = null,
        string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Expense> query = _db.Expenses.Where(e => e.TenantId == tenantId);

        if (fromDate.HasValue)
            query = query.Where(e => e.ExpenseDate >= fromDate.Value);
        if (toDate.HasValue)
            query = query.Where(e => e.ExpenseDate <= toDate.Value);
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(e => e.Description.Contains(search));

        return await query.CountAsync(cancellationToken);
    }

    public async Task<ExpenseSummary> GetSummaryAsync(
        Guid tenantId, DateTime fromDate, DateTime toDate, CancellationToken cancellationToken = default)
    {
        IQueryable<Expense> query = _db.Expenses.Where(e =>
            e.TenantId == tenantId && e.ExpenseDate >= fromDate && e.ExpenseDate <= toDate);

        var total = await query.SumAsync(e => (decimal?)e.Amount, cancellationToken) ?? 0m;

        var byCategory = await query
            .GroupBy(e => e.CategoryId)
            .Select(g => new { CategoryId = g.Key, Total = g.Sum(e => e.Amount) })
            .ToListAsync(cancellationToken);

        var categoryNames = (await ListCategoriesAsync(tenantId, cancellationToken))
            .ToDictionary(c => c.Id, c => c.Name);

        return new ExpenseSummary(
            total,
            byCategory
                .OrderByDescending(g => g.Total)
                .Select(g => new ExpenseCategoryTotal(
                    g.CategoryId,
                    g.CategoryId is null || !categoryNames.TryGetValue(g.CategoryId.Value, out var name)
                        ? null
                        : name,
                    g.Total))
                .ToList());
    }

    public Task AddCategoryAsync(ExpenseCategory category, CancellationToken cancellationToken = default)
        => _db.ExpenseCategories.AddAsync(category, cancellationToken).AsTask();

    public Task<ExpenseCategory?> GetCategoryByIdAsync(
        Guid tenantId, Guid categoryId, CancellationToken cancellationToken = default)
        => _db.ExpenseCategories.FirstOrDefaultAsync(
            c => c.TenantId == tenantId && c.Id == categoryId, cancellationToken);

    public Task<ExpenseCategory?> GetCategoryByNameAsync(
        Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.ExpenseCategories.FirstOrDefaultAsync(
            c => c.TenantId == tenantId && c.Name == name, cancellationToken);

    public async Task<IReadOnlyList<ExpenseCategory>> ListCategoriesAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.ExpenseCategories
            .Where(c => c.TenantId == tenantId)
            .OrderBy(c => c.Name)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<ExpenseTrendPoint>> GetExpenseTrendAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        var expenses = await _db.Expenses
            .Where(e => e.TenantId == tenantId && e.ExpenseDate >= from && e.ExpenseDate <= to)
            .ToListAsync(cancellationToken);

        return expenses
            .GroupBy(e => e.ExpenseDate.Date)
            .Select(g => new ExpenseTrendPoint(
                g.Key.ToString("yyyy-MM-dd"), g.Sum(e => e.Amount)))
            .OrderBy(x => x.Label)
            .ToList();
    }

    public async Task<IReadOnlyList<ExpenseByPaymentMethodRow>> GetExpenseByPaymentMethodAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        return await _db.Expenses
            .Where(e => e.TenantId == tenantId && e.ExpenseDate >= from && e.ExpenseDate <= to)
            .GroupBy(e => e.PaymentMethod ?? "Other")
            .Select(g => new ExpenseByPaymentMethodRow(
                g.Key, g.Sum(e => e.Amount)))
            .OrderByDescending(x => x.Amount)
            .ToListAsync(cancellationToken);
    }
}

public sealed class CustomerRepository : ICustomerRepository
{
    private readonly BusinessDbContext _db;

    public CustomerRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(Customer customer, CancellationToken cancellationToken = default)
        => _db.Customers.AddAsync(customer, cancellationToken).AsTask();

    public Task UpdateAsync(Customer customer, CancellationToken cancellationToken = default)
    {
        _db.Customers.Update(customer);
        return Task.CompletedTask;
    }

    public Task<Customer?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Customers.FirstOrDefaultAsync(c => c.TenantId == tenantId && c.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Customer>> ListAsync(
        Guid tenantId, int page, int pageSize, string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Customer> query = _db.Customers.Where(c => c.TenantId == tenantId);

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(c => c.Name.Contains(search) || (c.Phone != null && c.Phone.Contains(search)));

        return await query
            .OrderBy(c => c.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountAsync(Guid tenantId, string? search = null, CancellationToken cancellationToken = default)
    {
        IQueryable<Customer> query = _db.Customers.Where(c => c.TenantId == tenantId);

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(c => c.Name.Contains(search) || (c.Phone != null && c.Phone.Contains(search)));

        return await query.CountAsync(cancellationToken);
    }
}

public sealed class CustomerCreditRepository : ICustomerCreditRepository
{
    private readonly BusinessDbContext _db;

    public CustomerCreditRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(CustomerCredit credit, CancellationToken cancellationToken = default)
        => _db.CustomerCredits.AddAsync(credit, cancellationToken).AsTask();

    public Task UpdateAsync(CustomerCredit credit, CancellationToken cancellationToken = default)
    {
        _db.CustomerCredits.Update(credit);
        return Task.CompletedTask;
    }

    public Task<CustomerCredit?> GetByCustomerIdAsync(Guid tenantId, Guid customerId, CancellationToken cancellationToken = default)
        => _db.CustomerCredits.FirstOrDefaultAsync(cc => cc.TenantId == tenantId && cc.CustomerId == customerId, cancellationToken);

    public Task AddTransactionAsync(CreditTransaction transaction, CancellationToken cancellationToken = default)
        => _db.CreditTransactions.AddAsync(transaction, cancellationToken).AsTask();

    public async Task<IReadOnlyList<CreditTransaction>> ListTransactionsAsync(
        Guid tenantId, Guid customerId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.CreditTransactions
            .Where(ct => ct.TenantId == tenantId && ct.CustomerId == customerId)
            .OrderByDescending(ct => ct.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<CustomerCredit>> ListOutstandingAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.CustomerCredits
            .Where(cc => cc.TenantId == tenantId && cc.Balance > 0)
            .OrderByDescending(cc => cc.Balance)
            .ToListAsync(cancellationToken);
}

public sealed class MoneyAccountRepository : IMoneyAccountRepository
{
    private readonly BusinessDbContext _db;

    public MoneyAccountRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(MoneyAccount account, CancellationToken cancellationToken = default)
        => _db.MoneyAccounts.AddAsync(account, cancellationToken).AsTask();

    public Task UpdateAsync(MoneyAccount account, CancellationToken cancellationToken = default)
    {
        _db.MoneyAccounts.Update(account);
        return Task.CompletedTask;
    }

    public Task<MoneyAccount?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.MoneyAccounts.FirstOrDefaultAsync(a => a.TenantId == tenantId && a.Id == id, cancellationToken);

    public async Task<IReadOnlyList<MoneyAccount>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.MoneyAccounts
            .Where(a => a.TenantId == tenantId && a.IsActive)
            .OrderBy(a => a.Name)
            .ToListAsync(cancellationToken);

    public Task AddTransactionAsync(MoneyAccountTransaction transaction, CancellationToken cancellationToken = default)
        => _db.MoneyAccountTransactions.AddAsync(transaction, cancellationToken).AsTask();

    public async Task<IReadOnlyList<MoneyAccountTransaction>> ListTransactionsAsync(
        Guid tenantId, Guid accountId, int page, int pageSize, CancellationToken cancellationToken = default)
        => await _db.MoneyAccountTransactions
            .Where(t => t.TenantId == tenantId && t.AccountId == accountId)
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
}

public sealed class CashSessionRepository : ICashSessionRepository
{
    private readonly BusinessDbContext _db;

    public CashSessionRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(CashSession session, CancellationToken cancellationToken = default)
        => _db.CashSessions.AddAsync(session, cancellationToken).AsTask();

    public Task UpdateAsync(CashSession session, CancellationToken cancellationToken = default)
    {
        _db.CashSessions.Update(session);
        return Task.CompletedTask;
    }

    public Task<CashSession?> GetOpenSessionAsync(Guid tenantId, Guid accountId, CancellationToken cancellationToken = default)
        => _db.CashSessions.FirstOrDefaultAsync(
            s => s.TenantId == tenantId && s.AccountId == accountId && s.Status == CashSessionStatus.Open,
            cancellationToken);

    public Task<CashSession?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.CashSessions.FirstOrDefaultAsync(s => s.TenantId == tenantId && s.Id == id, cancellationToken);

    public async Task<IReadOnlyList<CashSession>> ListAsync(
        Guid tenantId, Guid? accountId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        IQueryable<CashSession> query = _db.CashSessions.Where(s => s.TenantId == tenantId);
        if (accountId.HasValue)
            query = query.Where(s => s.AccountId == accountId.Value);

        return await query
            .OrderByDescending(s => s.OpenedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }
}

public sealed class ReceiptLayoutRepository : IReceiptLayoutRepository
{
    private readonly BusinessDbContext _db;

    public ReceiptLayoutRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(ReceiptLayout layout, CancellationToken cancellationToken = default)
        => _db.ReceiptLayouts.AddAsync(layout, cancellationToken).AsTask();

    public Task UpdateAsync(ReceiptLayout layout, CancellationToken cancellationToken = default)
    {
        _db.ReceiptLayouts.Update(layout);
        return Task.CompletedTask;
    }

    public async Task<ReceiptLayout?> GetActiveAsync(
        Guid tenantId, string layoutId, CancellationToken cancellationToken = default)
        => await _db.ReceiptLayouts
            .AsNoTracking()
            .FirstOrDefaultAsync(
                r => r.TenantId == tenantId && r.LayoutId == layoutId && r.IsActive,
                cancellationToken);

    public async Task<ReceiptLayout?> GetByIdAsync(
        Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => await _db.ReceiptLayouts
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.TenantId == tenantId && r.Id == id, cancellationToken);

    public async Task<IReadOnlyList<ReceiptLayout>> ListAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.ReceiptLayouts
            .AsNoTracking()
            .Where(r => r.TenantId == tenantId)
            .OrderBy(r => r.LayoutId)
            .ThenByDescending(r => r.Version)
            .ToListAsync(cancellationToken);

    public async Task<bool> HasActiveLayoutAsync(
        Guid tenantId, string layoutId, CancellationToken cancellationToken = default)
        => await _db.ReceiptLayouts
            .AsNoTracking()
            .AnyAsync(r => r.TenantId == tenantId && r.LayoutId == layoutId && r.IsActive, cancellationToken);
}

public sealed class ReceiptMetadataRepository : IReceiptMetadataRepository
{
    private readonly BusinessDbContext _db;

    public ReceiptMetadataRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(ReceiptMetadata metadata, CancellationToken cancellationToken = default)
        => _db.ReceiptMetadataSet.AddAsync(metadata, cancellationToken).AsTask();

    public async Task<ReceiptMetadata?> GetBySaleIdAsync(
        Guid saleId, CancellationToken cancellationToken = default)
        => await _db.ReceiptMetadataSet
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.SaleId == saleId, cancellationToken);
}

public sealed class ReceiptPrintEventRepository : IReceiptPrintEventRepository
{
    private readonly BusinessDbContext _db;

    public ReceiptPrintEventRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(ReceiptPrintEvent printEvent, CancellationToken cancellationToken = default)
        => _db.ReceiptPrintEvents.AddAsync(printEvent, cancellationToken).AsTask();

    public async Task<int> CountBySaleIdAsync(
        Guid saleId, CancellationToken cancellationToken = default)
        => await _db.ReceiptPrintEvents
            .AsNoTracking()
            .CountAsync(r => r.SaleId == saleId, cancellationToken);

    public async Task<IReadOnlyList<ReceiptPrintEvent>> ListBySaleIdAsync(
        Guid saleId, CancellationToken cancellationToken = default)
        => await _db.ReceiptPrintEvents
            .AsNoTracking()
            .Where(r => r.SaleId == saleId)
            .OrderBy(r => r.PrintedAt)
            .ToListAsync(cancellationToken);
}

public sealed class PlanRepository : IPlanRepository
{
    private readonly BusinessDbContext _db;

    public PlanRepository(BusinessDbContext db) => _db = db;

    public async Task<Plan?> GetByCodeAsync(string code, CancellationToken cancellationToken = default)
    {
        var normalized = code.Trim().ToLowerInvariant();
        return await _db.Plans.FirstOrDefaultAsync(
            p => p.Code.ToLower() == normalized, cancellationToken);
    }

    public async Task<IReadOnlyList<Plan>> ListActiveAsync(CancellationToken cancellationToken = default)
        => await _db.Plans
            .AsNoTracking()
            .Where(p => p.IsActive)
            .OrderBy(p => p.MonthlyPrice)
            .ToListAsync(cancellationToken);

    public Task AddAsync(Plan plan, CancellationToken cancellationToken = default)
        => _db.Plans.AddAsync(plan, cancellationToken).AsTask();
}

public sealed class SubscriptionRepository : ISubscriptionRepository
{
    private readonly BusinessDbContext _db;

    public SubscriptionRepository(BusinessDbContext db) => _db = db;

    public Task<Subscription?> GetForTenantAsync(Guid tenantId, CancellationToken cancellationToken = default)
    {
        var pending = _db.Subscriptions.Local
            .FirstOrDefault(s => s.TenantId == tenantId);
        if (pending is not null)
        {
            return Task.FromResult<Subscription?>(pending);
        }

        return _db.Subscriptions.FirstOrDefaultAsync(s => s.TenantId == tenantId, cancellationToken);
    }

    public Task AddAsync(Subscription subscription, CancellationToken cancellationToken = default)
        => _db.Subscriptions.AddAsync(subscription, cancellationToken).AsTask();

    public Task UpdateAsync(Subscription subscription, CancellationToken cancellationToken = default)
    {
        _db.Subscriptions.Update(subscription);
        return Task.CompletedTask;
    }
}

public sealed class SubscriptionItemRepository : ISubscriptionItemRepository
{
    private readonly BusinessDbContext _db;

    public SubscriptionItemRepository(BusinessDbContext db) => _db = db;

    public async Task<IReadOnlyList<SubscriptionItem>> ListForTenantAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.SubscriptionItems
            .Where(item => item.TenantId == tenantId)
            .OrderBy(item => item.PlanCode)
            .ToListAsync(cancellationToken);

    public Task<SubscriptionItem?> GetForTenantByPlanAsync(
        Guid tenantId, string planCode, CancellationToken cancellationToken = default)
        => _db.SubscriptionItems.FirstOrDefaultAsync(
            item => item.TenantId == tenantId && item.PlanCode == planCode,
            cancellationToken);

    public Task AddAsync(SubscriptionItem item, CancellationToken cancellationToken = default)
        => _db.SubscriptionItems.AddAsync(item, cancellationToken).AsTask();

    public Task RemoveAsync(SubscriptionItem item, CancellationToken cancellationToken = default)
    {
        _db.SubscriptionItems.Remove(item);
        return Task.CompletedTask;
    }
}

public sealed class VoucherRepository : IVoucherRepository
{
    private readonly BusinessDbContext _db;

    public VoucherRepository(BusinessDbContext db) => _db = db;

    public Task<Voucher?> GetByCodeAsync(string code, CancellationToken cancellationToken = default)
        => _db.Vouchers.FirstOrDefaultAsync(v => v.Code == code, cancellationToken);

    public Task AddAsync(Voucher voucher, CancellationToken cancellationToken = default)
        => _db.Vouchers.AddAsync(voucher, cancellationToken).AsTask();
}

public sealed class InvoiceRepository : IInvoiceRepository
{
    private readonly BusinessDbContext _db;
    private readonly INumberSequenceRepository _numberSequences;

    public InvoiceRepository(BusinessDbContext db, INumberSequenceRepository numberSequences)
    {
        _db = db;
        _numberSequences = numberSequences;
    }

    public Task<Invoice?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.Invoices.FirstOrDefaultAsync(i => i.TenantId == tenantId && i.Id == id, cancellationToken);

    public Task<Invoice?> GetByIdAnyTenantAsync(Guid id, CancellationToken cancellationToken = default)
        => _db.Invoices.FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

    public async Task<Invoice?> GetOpenAsync(Guid tenantId, CancellationToken cancellationToken = default)
    {
        var pendingOpen = _db.Invoices.Local
            .FirstOrDefault(i => i.TenantId == tenantId && i.Status == InvoiceStatus.Open);
        if (pendingOpen is not null)
        {
            return pendingOpen;
        }

        // Exclude invoices already tracked for this tenant (e.g. just marked paid in the
        // same command) so the database's pre-save row cannot surface as still open.
        var localIds = _db.Invoices.Local
            .Where(i => i.TenantId == tenantId)
            .Select(i => i.Id)
            .ToList();

        if (localIds.Count == 0)
        {
            return await _db.Invoices
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    i => i.TenantId == tenantId && i.Status == InvoiceStatus.Open,
                    cancellationToken);
        }

        return await _db.Invoices
            .AsNoTracking()
            .FirstOrDefaultAsync(
                i => i.TenantId == tenantId
                    && i.Status == InvoiceStatus.Open
                    && !localIds.Contains(i.Id),
                cancellationToken);
    }

    public async Task<IReadOnlyList<Invoice>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.Invoices
            .AsNoTracking()
            .Where(i => i.TenantId == tenantId)
            .OrderByDescending(i => i.IssuedAtUtc)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<DebtView>> ListDebtsAsync(CancellationToken cancellationToken = default)
        => await _db.Invoices
            .AsNoTracking()
            .Where(i => i.Status == InvoiceStatus.Open)
            .Join(
                _db.Tenants,
                invoice => invoice.TenantId,
                tenant => tenant.Id,
                (invoice, tenant) => new DebtView(
                    invoice.Id,
                    invoice.Number,
                    invoice.TenantId,
                    tenant.Name,
                    invoice.Amount,
                    invoice.Currency,
                    invoice.IssuedAtUtc,
                    invoice.Reference))
            .OrderBy(d => d.IssuedAtUtc)
            .ToListAsync(cancellationToken);

    public Task<string> AllocateNumberAsync(Guid tenantId, DateTime date, CancellationToken cancellationToken = default)
        => _numberSequences.AllocateAsync(tenantId, "Invoice", date, cancellationToken);

    public Task AddAsync(Invoice invoice, CancellationToken cancellationToken = default)
        => _db.Invoices.AddAsync(invoice, cancellationToken).AsTask();

    public Task UpdateAsync(Invoice invoice, CancellationToken cancellationToken = default)
    {
        _db.Invoices.Update(invoice);
        return Task.CompletedTask;
    }
}

public sealed class CustomerInvoiceRepository : ICustomerInvoiceRepository
{
    private readonly BusinessDbContext _db;
    private readonly INumberSequenceRepository _numberSequences;

    public CustomerInvoiceRepository(BusinessDbContext db, INumberSequenceRepository numberSequences)
    {
        _db = db;
        _numberSequences = numberSequences;
    }

    public Task AddAsync(CustomerInvoice invoice, CancellationToken cancellationToken = default)
        => _db.CustomerInvoices.AddAsync(invoice, cancellationToken).AsTask();

    public Task UpdateAsync(CustomerInvoice invoice, CancellationToken cancellationToken = default)
    {
        _db.CustomerInvoices.Update(invoice);
        return Task.CompletedTask;
    }

    public Task<CustomerInvoice?> GetByIdAsync(
        Guid tenantId, Guid id, CancellationToken cancellationToken = default)
        => _db.CustomerInvoices
            .Include(i => i.Lines)
            .FirstOrDefaultAsync(i => i.TenantId == tenantId && i.Id == id, cancellationToken);

    public Task<CustomerInvoice?> GetByNumberAsync(
        Guid tenantId, string number, CancellationToken cancellationToken = default)
        => _db.CustomerInvoices
            .Include(i => i.Lines)
            .FirstOrDefaultAsync(
                i => i.TenantId == tenantId && i.Number == number, cancellationToken);

    public async Task<IReadOnlyList<CustomerInvoice>> ListAsync(
        Guid tenantId, int page, int pageSize, CustomerInvoiceListFilter filter,
        CancellationToken cancellationToken = default)
    {
        var query = _db.CustomerInvoices
            .AsNoTracking()
            .Where(i => i.TenantId == tenantId);

        if (filter.Status is { } status)
        {
            query = query.Where(i => i.Status == status);
        }

        if (filter.CustomerId is { } customerId)
        {
            query = query.Where(i => i.CustomerId == customerId);
        }

        if (!string.IsNullOrWhiteSpace(filter.Search))
        {
            var search = filter.Search.Trim();
            query = query.Where(i =>
                EF.Functions.ILike(i.Number, $"%{search}%") ||
                EF.Functions.ILike(i.CustomerName!, $"%{search}%"));
        }

        return await query
            .OrderByDescending(i => i.IssueDate)
            .ThenByDescending(i => i.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountAsync(
        Guid tenantId, CustomerInvoiceListFilter filter, CancellationToken cancellationToken = default)
    {
        var query = _db.CustomerInvoices.Where(i => i.TenantId == tenantId);

        if (filter.Status is { } status)
        {
            query = query.Where(i => i.Status == status);
        }

        if (filter.CustomerId is { } customerId)
        {
            query = query.Where(i => i.CustomerId == customerId);
        }

        if (!string.IsNullOrWhiteSpace(filter.Search))
        {
            var search = filter.Search.Trim();
            query = query.Where(i =>
                EF.Functions.ILike(i.Number, $"%{search}%") ||
                EF.Functions.ILike(i.CustomerName!, $"%{search}%"));
        }

        return await query.CountAsync(cancellationToken);
    }

    public Task<string> AllocateNumberAsync(
        Guid tenantId, DateTime date, CancellationToken cancellationToken = default)
        => _numberSequences.AllocateAsync(tenantId, "CustomerInvoice", date, cancellationToken);
}
