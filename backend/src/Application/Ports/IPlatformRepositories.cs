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
using BusinessOS.Domain.Notifications;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared.Events;

namespace BusinessOS.Application.Ports;

public sealed record DispatchedEvent(Guid OutboxMessageId, IDomainEvent Event);

public interface IUnitOfWork
{
    Task<IReadOnlyList<DispatchedEvent>> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task MarkProcessedAsync(IReadOnlyCollection<Guid> outboxMessageIds, CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}

public interface IEmailVerificationCodeRepository
{
    Task<EmailVerificationCode?> GetByCodeHashAsync(string codeHash, CancellationToken cancellationToken = default);
    Task<EmailVerificationCode?> GetLatestForUserAsync(
        Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task InvalidateAllForUserAsync(Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(EmailVerificationCode code, CancellationToken cancellationToken = default);
}

public interface IPasswordResetCodeRepository
{
    Task<PasswordResetCode?> GetLatestForUserAsync(
        Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task InvalidateAllForUserAsync(Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(PasswordResetCode code, CancellationToken cancellationToken = default);
}

public interface IInvitationCodeRepository
{
    Task<InvitationCode?> GetActiveByCodeHashAsync(string codeHash, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<InvitationCode>> ListActiveForTenantAsync(
        Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(InvitationCode code, CancellationToken cancellationToken = default);
}

public interface ITenantRepository
{
    Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Tenant?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default);
    Task UpdateAsync(Tenant tenant, CancellationToken cancellationToken = default);
}

public interface IBranchRepository
{
    Task<Branch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Branch?> GetByCodeAsync(Guid tenantId, string code, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListAllAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Branch branch, CancellationToken cancellationToken = default);
}

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<User?> GetByPhoneAsync(string phone, CancellationToken cancellationToken = default);
    Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<User>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<int> CountActiveAdministratorsAsync(
        Guid tenantId, Guid excludeUserId, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
}

public interface IRoleRepository
{
    Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Role>> GetManyByIdsAsync(
        Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<string>> GetPermissionsAsync(
        Guid tenantId, Guid roleId, CancellationToken cancellationToken = default);
    Task AddAsync(Role role, CancellationToken cancellationToken = default);
    Task RemoveAsync(Role role, CancellationToken cancellationToken = default);
}

public interface IPermissionRepository
{
    Task<IReadOnlyList<Permission>> ListAsync(CancellationToken cancellationToken = default);
    Task<Permission?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Permission>> ResolveByNamesAsync(
        IEnumerable<string> names, CancellationToken cancellationToken = default);
}

public interface IRefreshTokenRepository
{
    Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default);
    Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default);
    Task RevokeFamilyAsync(Guid familyId, Guid revokedByTokenId, CancellationToken cancellationToken = default);
    Task RevokeAllForUserAsync(Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default);

    /// <summary>
    /// Active (unrevoked, unexpired) token rows for a user, newest first. One row per
    /// rotated token in a family, so callers group by <c>FamilyId</c> to get sessions.
    /// </summary>
    Task<IReadOnlyList<RefreshToken>> ListActiveByUserAsync(
        Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
}

/// <summary>Single-use second-factor recovery codes. Only hashes are persisted.</summary>
public interface ITwoFactorRecoveryCodeRepository
{
    Task AddRangeAsync(IEnumerable<TwoFactorRecoveryCode> codes, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TwoFactorRecoveryCode>> ListForUserAsync(
        Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
    Task RemoveAllForUserAsync(Guid tenantId, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Marks one unused code as used in a single conditional statement. Returns the number
    /// of rows affected; 0 means the code was already spent, so a replay cannot re-enter.
    /// </summary>
    Task<int> TryConsumeAsync(
        Guid tenantId, Guid userId, string codeHash, CancellationToken cancellationToken = default);
}

/// <summary>
/// Pending second-factor steps. Tracked (not projected) because consumption is a
/// read-modify-write; a projection would let two concurrent verifies both see the same
/// challenge as usable and both mint a token family.
/// </summary>
public interface ITwoFactorChallengeRepository
{
    Task AddAsync(TwoFactorChallenge challenge, CancellationToken cancellationToken = default);

    /// <summary>Loads a challenge by the SHA-256 hash of the raw token, tracked for update.</summary>
    Task<TwoFactorChallenge?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default);

    /// <summary>Consumes a challenge only if it is still usable, atomically. Returns the
    /// number of rows affected: 0 means a concurrent request already spent it.</summary>
    Task<int> TryConsumeAsync(Guid id, CancellationToken cancellationToken = default);

    Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default);
}

public interface IAuditLogRepository
{
    Task AddAsync(AuditLog auditLog, CancellationToken cancellationToken = default);
}

public interface IFeatureFlagRepository
{
    Task<FeatureFlag?> GetAsync(Guid tenantId, string key, CancellationToken cancellationToken = default);
    Task AddAsync(FeatureFlag flag, CancellationToken cancellationToken = default);
    Task UpdateAsync(FeatureFlag flag, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<FeatureFlag>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public sealed record ProductListFilter(
    string? Search,
    Guid? CategoryId,
    Guid? BrandId,
    ProductType? ProductType,
    ProductStatus? Status);

public interface IProductRepository
{
    Task<Product?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Product?> GetBySkuAsync(Guid tenantId, string sku, CancellationToken cancellationToken = default);
    Task<Product?> GetByBarcodeAsync(Guid tenantId, string barcode, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Product>> ListAsync(
        Guid tenantId, int page, int pageSize, ProductListFilter filter, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, ProductListFilter filter, CancellationToken cancellationToken = default);
    Task AddAsync(Product product, CancellationToken cancellationToken = default);
    Task<bool> VariantSkuExistsAsync(
        Guid tenantId, string sku, Guid? excludeProductId = null, CancellationToken cancellationToken = default);
    Task<bool> VariantBarcodeExistsAsync(
        Guid tenantId, string barcode, Guid? excludeProductId = null, CancellationToken cancellationToken = default);
}

public interface ICategoryRepository
{
    Task<ProductCategory?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<ProductCategory?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ProductCategory>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(ProductCategory category, CancellationToken cancellationToken = default);
    Task RemoveAsync(ProductCategory category, CancellationToken cancellationToken = default);
}

public interface IBrandRepository
{
    Task<Brand?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Brand?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Brand>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Brand brand, CancellationToken cancellationToken = default);
    Task RemoveAsync(Brand brand, CancellationToken cancellationToken = default);
}

public interface IUnitOfMeasureRepository
{
    Task<UnitOfMeasure?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<UnitOfMeasure?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<UnitOfMeasure>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(UnitOfMeasure unitOfMeasure, CancellationToken cancellationToken = default);
    Task RemoveAsync(UnitOfMeasure unitOfMeasure, CancellationToken cancellationToken = default);
}

public interface IWarehouseRepository
{
    Task<Warehouse?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Warehouse?> GetByCodeAsync(Guid tenantId, string code, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Warehouse>> ListAsync(
        Guid tenantId,
        int page,
        int pageSize,
        string? search,
        Guid? branchId,
        CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, string? search, Guid? branchId, CancellationToken cancellationToken = default);
    Task AddAsync(Warehouse warehouse, CancellationToken cancellationToken = default);
}

public interface IStockRepository
{
    Task<StockBalance?> GetBalanceAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default);
    Task<StockBalance?> GetBalanceWithLockAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default);
    Task<StockBalance> GetOrCreateBalanceAsync(
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        CancellationToken cancellationToken = default);
    Task AddMovementAsync(StockMovement movement, CancellationToken cancellationToken = default);
    /// <summary>Finds the adjustment ledger row posted for a client idempotency key, if any.</summary>
    Task<StockMovement?> FindAdjustmentByKeyAsync(
        Guid tenantId,
        string key,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockBalanceView>> ListBalancesAsync(
        Guid tenantId,
        int page,
        int pageSize,
        Guid? warehouseId = null,
        Guid? productId = null,
        string? search = null,
        CancellationToken cancellationToken = default);
    Task<int> CountBalancesAsync(
        Guid tenantId,
        Guid? warehouseId = null,
        Guid? productId = null,
        string? search = null,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockMovementView>> ListMovementsAsync(
        Guid tenantId,
        int page,
        int pageSize,
        Guid? warehouseId = null,
        Guid? productId = null,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default);
    Task<int> CountMovementsAsync(
        Guid tenantId,
        Guid? warehouseId = null,
        Guid? productId = null,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockMovement>> ListMovementsByReferenceAsync(
        Guid tenantId,
        string referenceType,
        Guid referenceId,
        StockMovementType? type = null,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockSummaryRow>> GetStockSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockMovementSummaryRow>> GetStockMovementSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<LowStockReportItem>> GetLowStockReportAsync(
        Guid tenantId, decimal threshold, Guid? warehouseId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockVelocityRow>> GetStockVelocityAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default);
}

public interface IPriceListRepository
{
    Task<PriceList?> GetByIdAsync(
        Guid tenantId, Guid id, bool includePrices = false, CancellationToken cancellationToken = default);
    Task<PriceList?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<PriceList?> GetDefaultAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PriceList>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ProductPrice>> ResolvePricesAsync(
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate,
        CancellationToken cancellationToken = default);
    Task AddAsync(PriceList priceList, CancellationToken cancellationToken = default);
}

public interface IProductPriceRepository
{
    Task<IReadOnlyList<ProductPrice>> ListAsync(
        Guid tenantId,
        Guid priceListId,
        Guid? productId = null,
        Guid? branchId = null,
        PriceType? priceType = null,
        CancellationToken cancellationToken = default);
    Task UpsertManyAsync(
        PriceList priceList, IEnumerable<ProductPriceSpec> prices, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ProductPrice>> ResolveAsync(
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate,
        CancellationToken cancellationToken = default);
}

public sealed record DashboardCatalogSnapshot(
    int TotalProducts,
    int ActiveProducts,
    int DraftProducts,
    int InactiveProducts,
    int ServiceProducts,
    int TotalVariants,
    int TotalCategories);

public sealed record DashboardInventorySnapshot(
    int TotalWarehouses,
    int TotalStockLines,
    decimal TotalOnHandUnits,
    int StockedProducts,
    int ZeroStockLines,
    int TotalMovements);

public sealed record DashboardPricingSnapshot(
    int TotalPriceLists,
    string? DefaultPriceListName,
    int ActivePriceProducts,
    int BranchOverrideProducts);

public sealed record DashboardOrganizationSnapshot(
    int TotalBranches,
    int TotalUsers,
    int ActiveUsers,
    int TotalRoles);

public sealed record DashboardSnapshot(
    DashboardCatalogSnapshot Catalog,
    DashboardInventorySnapshot Inventory,
    DashboardPricingSnapshot Pricing,
    DashboardOrganizationSnapshot Organization);

public sealed record LowStockItem(Guid ProductId, string ProductName, string? Sku, decimal OnHand);

public sealed record StockBalanceView(
    Guid WarehouseId,
    string WarehouseName,
    Guid StockLocationId,
    string StockLocationName,
    Guid ProductId,
    string ProductName,
    string? Sku,
    string? Barcode,
    Guid? VariantId,
    string UnitOfMeasureName,
    decimal Quantity);

public sealed record StockMovementView(
    Guid Id,
    Guid ProductId,
    string ProductName,
    string? Sku,
    string? Barcode,
    Guid WarehouseId,
    string WarehouseName,
    Guid StockLocationId,
    string StockLocationName,
    Guid? VariantId,
    StockMovementType Type,
    decimal QuantityDelta,
    string? Reason,
    DateTime EffectiveAt,
    Guid? CreatedBy,
    DateTime CreatedAt);

public sealed record RecentActivityItem(
    string Action,
    string EntityType,
    string? EntityId,
    string? EntityName,
    decimal? Amount,
    string? Status,
    string? ActorEmail,
    DateTime OccurredAt);

/// <summary>
/// Read-only operational KPIs over existing tables. Tenant-scoped; never mutates, raises
/// events, or writes audit rows. Queries only, so it stays a projection of the source of truth.
/// </summary>
public interface IDashboardRepository
{
    Task<DashboardSnapshot> GetSummaryAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<LowStockItem>> ListLowStockAsync(
        Guid tenantId, decimal maxQuantity, int limit, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RecentActivityItem>> ListRecentActivityAsync(
        Guid tenantId, int limit, CancellationToken cancellationToken = default);
}

/// <summary>
/// Read model for the tax engine: the tenant's regime, its effective rules on a date, the
/// global category catalog, and the tenant's exemptions. Queries only.
/// </summary>
public interface ITaxRuleRepository
{
    Task<TaxRegime?> GetRegimeForTenantAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<TaxCategory?> GetCategoryByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TaxCategory>> ListCategoriesAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TaxCategory>> ListCategoriesByCodesAsync(
        IEnumerable<string> codes, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TaxRule>> ListEffectiveRulesAsync(
        Guid regimeId, DateTime onDate, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TaxExemption>> ListExemptionsAsync(
        Guid tenantId, CancellationToken cancellationToken = default);
}

public sealed record SaleListFilter(
    Guid? BranchId,
    DateTime? FromDate,
    DateTime? ToDate,
    SaleStatus? Status,
    string? Search);

/// <summary>
/// Completed sale persistence. <see cref="GetByClientSaleIdAsync"/> is the idempotency replay
/// path — the client's <c>ClientSaleId</c> is unique per tenant.
/// </summary>
public interface ISaleRepository
{
    Task AddAsync(Sale sale, CancellationToken cancellationToken = default);
    Task UpdateAsync(Sale sale, CancellationToken cancellationToken = default);
    Task<Sale?> GetByIdAsync(
        Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Sale?> GetByClientSaleIdAsync(
        Guid tenantId, Guid clientSaleId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Sale>> ListAsync(
        Guid tenantId, int page, int pageSize, SaleListFilter filter, CancellationToken cancellationToken = default);
    Task<int> CountAsync(
        Guid tenantId, SaleListFilter filter, CancellationToken cancellationToken = default);
}

/// <summary>
/// Receipt numbering. <see cref="AllocateAsync"/> advances the tenant's sequence for
/// <paramref name="scope"/> under <c>SELECT ... FOR UPDATE</c>, creating the row on first use,
/// and returns the next rendered number. Concurrency is additionally serialized per tenant by
/// the sale command's advisory lock, so two tenants never share a number.
/// </summary>
public interface INumberSequenceRepository
{
    Task<string> AllocateAsync(
        Guid tenantId, string scope, DateTime date, CancellationToken cancellationToken = default);
}

public interface ITransferRepository
{
    Task AddAsync(Transfer transfer, CancellationToken cancellationToken = default);
    Task UpdateAsync(Transfer transfer, CancellationToken cancellationToken = default);
    Task<Transfer?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Transfer>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public interface IStockCountRepository
{
    Task AddAsync(StockCount count, CancellationToken cancellationToken = default);
    Task UpdateAsync(StockCount count, CancellationToken cancellationToken = default);
    Task<StockCount?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockCount>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public interface IStockBatchRepository
{
    Task AddAsync(StockBatch batch, CancellationToken cancellationToken = default);
    Task UpdateAsync(StockBatch batch, CancellationToken cancellationToken = default);
    Task<StockBatch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<StockBatch?> GetByBatchNumberAsync(Guid tenantId, Guid productId, string batchNumber, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StockBatch>> ListAsync(Guid tenantId, int page, int pageSize, Guid? productId = null, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, Guid? productId = null, CancellationToken cancellationToken = default);
}

public interface ISupplierRepository
{
    Task AddAsync(Supplier supplier, CancellationToken cancellationToken = default);
    Task UpdateAsync(Supplier supplier, CancellationToken cancellationToken = default);
    Task<Supplier?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Supplier>> ListAsync(Guid tenantId, int page, int pageSize, string? search = null, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, string? search = null, CancellationToken cancellationToken = default);
}

public interface IPurchaseOrderRepository
{
    Task AddAsync(PurchaseOrder order, CancellationToken cancellationToken = default);
    Task UpdateAsync(PurchaseOrder order, CancellationToken cancellationToken = default);
    Task<PurchaseOrder?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PurchaseOrder>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
    // Note: IPurchasingRepository may not exist as a separate interface.
    // If purchase order listing is done through a different interface, add there.
    // The PurchasesSummaryQuery uses IPurchasingRepository with ListPurchaseOrdersAsync.
}

public interface ISupplierBillRepository
{
    Task AddAsync(SupplierBill bill, CancellationToken cancellationToken = default);
    Task UpdateAsync(SupplierBill bill, CancellationToken cancellationToken = default);
    Task<SupplierBill?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<SupplierBill?> GetByPurchaseOrderAsync(Guid tenantId, Guid purchaseOrderId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SupplierBill>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public interface ISupplierPaymentRepository
{
    Task AddAsync(SupplierPayment payment, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SupplierBill>> ListByBillAsync(Guid tenantId, Guid supplierBillId, CancellationToken cancellationToken = default);
}

public interface IAccountRepository
{
    Task AddAsync(Account account, CancellationToken cancellationToken = default);
    Task UpdateAsync(Account account, CancellationToken cancellationToken = default);
    Task<Account?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Account>> ListAsync(Guid tenantId, bool? isActive = null, CancellationToken cancellationToken = default);
}

public interface IJournalEntryRepository
{
    Task AddAsync(JournalEntry entry, CancellationToken cancellationToken = default);
    Task UpdateAsync(JournalEntry entry, CancellationToken cancellationToken = default);
    Task<JournalEntry?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<JournalEntry?> GetBySourceAsync(Guid tenantId, string sourceType, Guid sourceId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<JournalEntry>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public interface ITenantAccountMappingRepository
{
    Task AddAsync(TenantAccountMapping mapping, CancellationToken cancellationToken = default);
    Task<TenantAccountMapping?> GetByMappingKeyAsync(Guid tenantId, string mappingKey, CancellationToken cancellationToken = default);
}

public sealed record TaxSummaryLine(
    string TaxCode, decimal AppliedRate,
    decimal TotalBaseAmount, decimal TotalTaxAmount, decimal TotalLineTotal, int SaleCount);

public sealed record SalesByBranchSummary(
    Guid BranchId, string BranchName, int TotalSales, decimal TotalRevenue);

public sealed record TopProductRow(
    Guid ProductId, string ProductName, string? Sku,
    decimal TotalQuantity, decimal TotalRevenue, decimal TotalTax, int Rank,
    decimal TotalCost = 0m, decimal TotalProfit = 0m, decimal MarginPercent = 0m);

public sealed record SalesTrendPoint(string Label, int SaleCount, decimal Revenue, decimal Tax);

public sealed record SalesByPaymentMethodRow(string PaymentMethod, decimal Amount, int Count);
public sealed record SalesByCategoryRow(string CategoryName, decimal Amount, decimal Quantity);
public sealed record SalesByStaffRow(Guid StaffId, string StaffName, int SaleCount, decimal Revenue);
public sealed record SalesByCustomerRow(Guid? CustomerId, string CustomerName, int SaleCount, decimal Revenue);
public sealed record StockSummaryRow(Guid ProductId, string ProductName, string? Sku, decimal Opening, decimal Purchased, decimal Sold, decimal Adjusted, decimal Closing);
public sealed record StockMovementSummaryRow(string MovementType, int Count, decimal TotalQuantity);
public sealed record LowStockReportItem(Guid ProductId, string ProductName, string? Sku, decimal OnHand, string WarehouseName);
public sealed record StockVelocityRow(Guid ProductId, string ProductName, string? Sku, decimal Sold, decimal OnHand, decimal VelocityPerDay);
public sealed record ExpenseTrendPoint(string Label, decimal Amount);
public sealed record ExpenseByPaymentMethodRow(string PaymentMethod, decimal Amount);

public interface IReportRepository
{
    Task<IReadOnlyList<TaxSummaryLine>> GetTaxSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<(int TotalSales, decimal TotalRevenue, decimal TotalTax, decimal TotalDiscount, decimal AverageSale,
        IReadOnlyList<SalesByBranchSummary> ByBranch)> GetSalesSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TopProductRow>> GetTopProductsAsync(
        Guid tenantId, DateTime from, DateTime to, int limit, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesTrendPoint>> GetSalesTrendAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesByPaymentMethodRow>> GetSalesByPaymentMethodAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesByCategoryRow>> GetSalesByCategoryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesByStaffRow>> GetSalesByStaffAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesByCustomerRow>> GetSalesByCustomerAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default);
    Task<decimal> GetCogsAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default);
}

public sealed record ExpenseSummary(
    decimal Total, IReadOnlyList<ExpenseCategoryTotal> ByCategory);

public sealed record ExpenseCategoryTotal(
    Guid? CategoryId, string? CategoryName, decimal Total);

public interface IExpenseRepository
{
    Task AddAsync(Expense expense, CancellationToken cancellationToken = default);
    Task UpdateAsync(Expense expense, CancellationToken cancellationToken = default);
    Task RemoveAsync(Expense expense, CancellationToken cancellationToken = default);
    Task<Expense?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Expense>> ListAsync(
        Guid tenantId, int page, int pageSize, DateTime? fromDate = null, DateTime? toDate = null,
        string? search = null, CancellationToken cancellationToken = default);
    Task<int> CountAsync(
        Guid tenantId, DateTime? fromDate = null, DateTime? toDate = null,
        string? search = null, CancellationToken cancellationToken = default);
    Task<ExpenseSummary> GetSummaryAsync(
        Guid tenantId, DateTime fromDate, DateTime toDate, CancellationToken cancellationToken = default);

    Task AddCategoryAsync(ExpenseCategory category, CancellationToken cancellationToken = default);
    Task<ExpenseCategory?> GetCategoryByIdAsync(
        Guid tenantId, Guid categoryId, CancellationToken cancellationToken = default);
    Task<ExpenseCategory?> GetCategoryByNameAsync(
        Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpenseCategory>> ListCategoriesAsync(
        Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpenseTrendPoint>> GetExpenseTrendAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpenseByPaymentMethodRow>> GetExpenseByPaymentMethodAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default);
}

public interface ICustomerRepository
{
    Task AddAsync(Customer customer, CancellationToken cancellationToken = default);
    Task UpdateAsync(Customer customer, CancellationToken cancellationToken = default);
    Task<Customer?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Customer>> ListAsync(
        Guid tenantId, int page, int pageSize, string? search = null, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, string? search = null, CancellationToken cancellationToken = default);
}

public interface ICustomerCreditRepository
{
    Task AddAsync(CustomerCredit credit, CancellationToken cancellationToken = default);
    Task UpdateAsync(CustomerCredit credit, CancellationToken cancellationToken = default);
    Task<CustomerCredit?> GetByCustomerIdAsync(Guid tenantId, Guid customerId, CancellationToken cancellationToken = default);
    Task AddTransactionAsync(CreditTransaction transaction, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CreditTransaction>> ListTransactionsAsync(
        Guid tenantId, Guid customerId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CustomerCredit>> ListOutstandingAsync(Guid tenantId, CancellationToken cancellationToken = default);
}

public interface IMoneyAccountRepository
{
    Task AddAsync(MoneyAccount account, CancellationToken cancellationToken = default);
    Task UpdateAsync(MoneyAccount account, CancellationToken cancellationToken = default);
    Task<MoneyAccount?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<MoneyAccount>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddTransactionAsync(MoneyAccountTransaction transaction, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<MoneyAccountTransaction>> ListTransactionsAsync(
        Guid tenantId, Guid accountId, int page, int pageSize, CancellationToken cancellationToken = default);
}

public interface ICashSessionRepository
{
    Task AddAsync(CashSession session, CancellationToken cancellationToken = default);
    Task UpdateAsync(CashSession session, CancellationToken cancellationToken = default);
    Task<CashSession?> GetOpenSessionAsync(Guid tenantId, Guid accountId, CancellationToken cancellationToken = default);
    Task<CashSession?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CashSession>> ListAsync(Guid tenantId, Guid? accountId, int page, int pageSize, CancellationToken cancellationToken = default);
}

/// <summary>
/// Receipt layout persistence. Layouts are reusable JSON definitions that describe receipt
/// structure. Multiple versions can exist per layout identifier; only one is active at a time.
/// </summary>
public interface IReceiptLayoutRepository
{
    Task AddAsync(ReceiptLayout layout, CancellationToken cancellationToken = default);
    Task UpdateAsync(ReceiptLayout layout, CancellationToken cancellationToken = default);
    Task<ReceiptLayout?> GetActiveAsync(Guid tenantId, string layoutId, CancellationToken cancellationToken = default);
    Task<ReceiptLayout?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ReceiptLayout>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> HasActiveLayoutAsync(Guid tenantId, string layoutId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Receipt metadata persistence. Written once per sale at finalization time; immutable afterwards.
/// </summary>
public interface IReceiptMetadataRepository
{
    Task AddAsync(ReceiptMetadata metadata, CancellationToken cancellationToken = default);
    Task<ReceiptMetadata?> GetBySaleIdAsync(Guid saleId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Receipt print event persistence. Write-once audit trail — events are never updated or deleted.
/// </summary>
public interface IReceiptPrintEventRepository
{
    Task AddAsync(ReceiptPrintEvent printEvent, CancellationToken cancellationToken = default);
    Task<int> CountBySaleIdAsync(Guid saleId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ReceiptPrintEvent>> ListBySaleIdAsync(Guid saleId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Global plan catalog. Plans are platform-level (like tax regimes) and seeded once.
/// </summary>
public interface IPlanRepository
{
    Task<Plan?> GetByCodeAsync(string code, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Plan>> ListActiveAsync(CancellationToken cancellationToken = default);
    Task AddAsync(Plan plan, CancellationToken cancellationToken = default);
}

/// <summary>One active subscription per tenant.</summary>
public interface ISubscriptionRepository
{
    Task<Subscription?> GetForTenantAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Subscription subscription, CancellationToken cancellationToken = default);
    Task UpdateAsync(Subscription subscription, CancellationToken cancellationToken = default);
}

/// <summary>Add-on packages (e.g. invoice-manager) attached to the tenant's base plan.</summary>
public interface ISubscriptionItemRepository
{
    Task<IReadOnlyList<SubscriptionItem>> ListForTenantAsync(
        Guid tenantId, CancellationToken cancellationToken = default);
    Task<SubscriptionItem?> GetForTenantByPlanAsync(
        Guid tenantId, string planCode, CancellationToken cancellationToken = default);
    Task AddAsync(SubscriptionItem item, CancellationToken cancellationToken = default);
    Task RemoveAsync(SubscriptionItem item, CancellationToken cancellationToken = default);
}

public interface IVoucherRepository
{
    Task<Voucher?> GetByCodeAsync(string code, CancellationToken cancellationToken = default);
    Task AddAsync(Voucher voucher, CancellationToken cancellationToken = default);
}

public sealed record DebtView(
    Guid InvoiceId,
    string InvoiceNumber,
    Guid TenantId,
    string TenantName,
    decimal Amount,
    string Currency,
    DateTime IssuedAtUtc,
    string? Reference);

public interface IInvoiceRepository
{
    Task<Invoice?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    /// <summary>Platform-scoped lookup for the owner billing desk (any tenant).</summary>
    Task<Invoice?> GetByIdAnyTenantAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Invoice?> GetOpenAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Invoice>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    /// <summary>Open invoices across tenants for the owner debt desk.</summary>
    Task<IReadOnlyList<DebtView>> ListDebtsAsync(CancellationToken cancellationToken = default);
    /// <summary>Advances the tenant's invoice numbering (scope <c>Invoice</c>, prefix <c>INV</c>).</summary>
    Task<string> AllocateNumberAsync(Guid tenantId, DateTime date, CancellationToken cancellationToken = default);
    Task AddAsync(Invoice invoice, CancellationToken cancellationToken = default);
    Task UpdateAsync(Invoice invoice, CancellationToken cancellationToken = default);
}

public sealed record CustomerInvoiceListFilter(
    CustomerInvoiceStatus? Status,
    Guid? CustomerId,
    string? Search);

public interface ICustomerInvoiceRepository
{
    Task<CustomerInvoice?> GetByIdAsync(
        Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<CustomerInvoice?> GetByNumberAsync(
        Guid tenantId, string number, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CustomerInvoice>> ListAsync(
        Guid tenantId, int page, int pageSize, CustomerInvoiceListFilter filter,
        CancellationToken cancellationToken = default);
    Task<int> CountAsync(
        Guid tenantId, CustomerInvoiceListFilter filter, CancellationToken cancellationToken = default);
    Task<string> AllocateNumberAsync(
        Guid tenantId, DateTime date, CancellationToken cancellationToken = default);
    Task AddAsync(CustomerInvoice invoice, CancellationToken cancellationToken = default);
    Task UpdateAsync(CustomerInvoice invoice, CancellationToken cancellationToken = default);
}

public sealed record NotificationListFilter(
    string? Category,
    bool? UnreadOnly);

public interface IAppNotificationRepository
{
    Task<AppNotification?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<AppNotification>> ListPagedAsync(
        Guid tenantId,
        Guid? userId,
        string? targetRole,
        int page,
        int pageSize,
        NotificationListFilter filter,
        CancellationToken cancellationToken = default);
    Task<int> GetUnreadCountAsync(
        Guid tenantId,
        Guid? userId,
        string? targetRole,
        CancellationToken cancellationToken = default);
    Task MarkAsReadAsync(Guid tenantId, Guid id, DateTime readAt, CancellationToken cancellationToken = default);
    Task<int> MarkAllAsReadAsync(Guid tenantId, Guid userId, DateTime readAt, CancellationToken cancellationToken = default);
    Task AddAsync(AppNotification notification, CancellationToken cancellationToken = default);
}

public interface IUserDeviceRepository
{
    Task<UserDevice?> GetByDeviceAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<UserDevice>> ListActiveForUsersAsync(
        Guid tenantId,
        IReadOnlyList<Guid> userIds,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<UserDevice>> ListActiveForRoleAsync(
        Guid tenantId,
        string roleName,
        CancellationToken cancellationToken = default);
    Task UpsertAsync(UserDevice device, CancellationToken cancellationToken = default);
    Task DeactivateAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default);
}

public interface INotificationPreferenceRepository
{
    Task<NotificationPreference?> GetByTenantAndUserAsync(Guid tenantId, Guid? userId, CancellationToken cancellationToken = default);
    Task UpsertAsync(NotificationPreference preference, CancellationToken cancellationToken = default);
}
