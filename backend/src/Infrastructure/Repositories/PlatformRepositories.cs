using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
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

    public Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default)
        => _db.Tenants.AddAsync(tenant, cancellationToken).AsTask();
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

        if (!string.IsNullOrWhiteSpace(filter.Search))
        {
            var term = filter.Search.Trim();
            filtered = filtered.Where(p =>
                p.Name.Contains(term)
                || (p.Sku != null && p.Sku.Contains(term))
                || (p.Barcode != null && p.Barcode.Contains(term)));
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
