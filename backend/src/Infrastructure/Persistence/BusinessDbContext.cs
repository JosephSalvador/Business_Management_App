using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Crm;
using BusinessOS.Domain.Finance;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Domain.Notifications;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared.Entities;
using BusinessOS.Shared.Events;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Persistence;

public sealed class BusinessDbContext : DbContext, IUnitOfWork
{
    public BusinessDbContext(DbContextOptions<BusinessDbContext> options) : base(options)
    {
    }

    public DbSet<Tenant> Tenants => Set<Tenant>();
    public DbSet<Branch> Branches => Set<Branch>();
    public DbSet<User> Users => Set<User>();
    public DbSet<UserBranch> UserBranches => Set<UserBranch>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<TwoFactorRecoveryCode> TwoFactorRecoveryCodes => Set<TwoFactorRecoveryCode>();
    public DbSet<TwoFactorChallenge> TwoFactorChallenges => Set<TwoFactorChallenge>();
    public DbSet<EmailVerificationCode> EmailVerificationCodes => Set<EmailVerificationCode>();
    public DbSet<PasswordResetCode> PasswordResetCodes => Set<PasswordResetCode>();
    public DbSet<InvitationCode> InvitationCodes => Set<InvitationCode>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<ProductCategory> ProductCategories => Set<ProductCategory>();
    public DbSet<Brand> Brands => Set<Brand>();
    public DbSet<UnitOfMeasure> UnitsOfMeasure => Set<UnitOfMeasure>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ProductVariant> ProductVariants => Set<ProductVariant>();
    public DbSet<Warehouse> Warehouses => Set<Warehouse>();
    public DbSet<StockLocation> StockLocations => Set<StockLocation>();
    public DbSet<StockBalance> StockBalances => Set<StockBalance>();
    public DbSet<StockMovement> StockMovements => Set<StockMovement>();
    public DbSet<Transfer> Transfers => Set<Transfer>();
    public DbSet<TransferLine> TransferLines => Set<TransferLine>();
    public DbSet<StockCount> StockCounts => Set<StockCount>();
    public DbSet<StockBatch> StockBatches => Set<StockBatch>();
    public DbSet<PriceList> PriceLists => Set<PriceList>();
    public DbSet<ProductPrice> ProductPrices => Set<ProductPrice>();
    public DbSet<FeatureFlag> FeatureFlags => Set<FeatureFlag>();
    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();
    public DbSet<TaxCategory> TaxCategories => Set<TaxCategory>();
    public DbSet<TaxRegime> TaxRegimes => Set<TaxRegime>();
    public DbSet<TaxRule> TaxRules => Set<TaxRule>();
    public DbSet<TaxExemption> TaxExemptions => Set<TaxExemption>();
    public DbSet<Sale> Sales => Set<Sale>();
    public DbSet<SaleLine> SaleLines => Set<SaleLine>();
    public DbSet<SalePayment> SalePayments => Set<SalePayment>();
    public DbSet<NumberSequence> NumberSequences => Set<NumberSequence>();
    public DbSet<ReceiptLayout> ReceiptLayouts => Set<ReceiptLayout>();
    public DbSet<ReceiptMetadata> ReceiptMetadataSet => Set<ReceiptMetadata>();
    public DbSet<ReceiptPrintEvent> ReceiptPrintEvents => Set<ReceiptPrintEvent>();
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();
    public DbSet<PurchaseOrderLine> PurchaseOrderLines => Set<PurchaseOrderLine>();
    public DbSet<SupplierBill> SupplierBills => Set<SupplierBill>();
    public DbSet<SupplierPayment> SupplierPayments => Set<SupplierPayment>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<JournalEntry> JournalEntries => Set<JournalEntry>();
    public DbSet<JournalEntryLine> JournalEntryLines => Set<JournalEntryLine>();
    public DbSet<TenantAccountMapping> TenantAccountMappings => Set<TenantAccountMapping>();
    public DbSet<Expense> Expenses => Set<Expense>();
    public DbSet<ExpenseCategory> ExpenseCategories => Set<ExpenseCategory>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<CustomerCredit> CustomerCredits => Set<CustomerCredit>();
    public DbSet<CreditTransaction> CreditTransactions => Set<CreditTransaction>();
    public DbSet<MoneyAccount> MoneyAccounts => Set<MoneyAccount>();
    public DbSet<MoneyAccountTransaction> MoneyAccountTransactions => Set<MoneyAccountTransaction>();
    public DbSet<CashSession> CashSessions => Set<CashSession>();
    public DbSet<Plan> Plans => Set<Plan>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<SubscriptionItem> SubscriptionItems => Set<SubscriptionItem>();
    public DbSet<Voucher> Vouchers => Set<Voucher>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<CustomerInvoice> CustomerInvoices => Set<CustomerInvoice>();
    public DbSet<CustomerInvoiceLine> CustomerInvoiceLines => Set<CustomerInvoiceLine>();
    public DbSet<AppNotification> Notifications => Set<AppNotification>();
    public DbSet<UserDevice> UserDevices => Set<UserDevice>();
    public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Tenant>(entity =>
        {
            entity.ToTable(Tables.Organization.Tenants, Schemas.Organization);
            entity.HasKey(t => t.Id);
            entity.Property(t => t.Name).IsRequired().HasMaxLength(200);
            entity.Property(t => t.ContactEmail).HasMaxLength(320);
            entity.Property(t => t.ContactPhone).HasMaxLength(30);
            entity.Property(t => t.Address).HasColumnType("text");
            entity.Property(t => t.Currency).IsRequired().HasMaxLength(3);
            entity.Property(t => t.TaxId).HasMaxLength(64);
            entity.Property(t => t.DatabaseSchema).HasMaxLength(64);
            entity.HasIndex(t => t.Name).IsUnique();
        });

        modelBuilder.Entity<Branch>(entity =>
        {
            entity.ToTable(Tables.Organization.Branches, Schemas.Organization);
            entity.HasKey(b => b.Id);
            entity.Property(b => b.Name).IsRequired().HasMaxLength(200);
            entity.Property(b => b.Code).IsRequired().HasMaxLength(50);
            entity.Property(b => b.Currency).IsRequired().HasMaxLength(3);
            entity.Property(b => b.Address).HasColumnType("text");
            entity.Property(b => b.Phone).HasMaxLength(30);
            entity.Property(b => b.Email).HasMaxLength(320);
            entity.HasIndex(b => new { b.TenantId, b.Code }).IsUnique();
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable(Tables.Identity.Users, Schemas.Identity);
            entity.HasKey(u => u.Id);
            entity.Property(u => u.Email).IsRequired().HasMaxLength(320);
            entity.Property(u => u.FullName).IsRequired().HasMaxLength(200);
            entity.Property(u => u.Phone).HasMaxLength(30);
            entity.Property(u => u.PasswordHash).IsRequired();
            entity.Property(u => u.TwoFactorSecret).HasMaxLength(512);
            entity.Property(u => u.TwoFactorPendingSecret).HasMaxLength(512);
            entity.HasIndex(u => u.Email).IsUnique();
            entity.HasIndex(u => u.Phone).IsUnique().HasFilter("\"Phone\" IS NOT NULL");
            entity.HasIndex(u => u.TenantId);
            entity.HasMany(u => u.Roles).WithMany().UsingEntity<object>(
                Tables.Identity.UserRoles,
                l => l.HasOne<Role>().WithMany().HasForeignKey("RoleId"),
                r => r.HasOne<User>().WithMany().HasForeignKey("UserId"),
                j => j.ToTable(Tables.Identity.UserRoles, Schemas.Identity));
            entity.HasMany(u => u.Branches)
                .WithOne()
                .HasForeignKey(ub => ub.UserId);
        });

        modelBuilder.Entity<UserBranch>(entity =>
        {
            entity.ToTable(Tables.Identity.UserBranches, Schemas.Identity);
            entity.HasKey(ub => ub.Id);
            entity.Property(ub => ub.Id).ValueGeneratedOnAdd();
            entity.Property(ub => ub.AssignedBy).IsRequired();
            entity.HasIndex(ub => ub.TenantId);
            entity.HasIndex(ub => ub.BranchId);
            entity.HasIndex(ub => new { ub.UserId, ub.BranchId }).IsUnique();
            entity.HasIndex(ub => ub.UserId)
                .IsUnique()
                .HasFilter("\"IsDefault\" = true");
            entity.HasOne<Branch>()
                .WithMany()
                .HasForeignKey(ub => ub.BranchId);
        });

        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable(Tables.Identity.Roles, Schemas.Identity);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.Name).IsRequired().HasMaxLength(100);
            entity.Property(r => r.Description).HasMaxLength(500);
            entity.HasIndex(r => new { r.TenantId, r.Name }).IsUnique();
            entity.HasMany(r => r.Permissions).WithMany().UsingEntity<object>(
                Tables.Identity.RolePermissions,
                l => l.HasOne<Permission>().WithMany().HasForeignKey("PermissionId"),
                r => r.HasOne<Role>().WithMany().HasForeignKey("RoleId"),
                j => j.ToTable(Tables.Identity.RolePermissions, Schemas.Identity));
        });

        modelBuilder.Entity<Permission>(entity =>
        {
            entity.ToTable(Tables.Identity.Permissions, Schemas.Identity);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Name).IsRequired().HasMaxLength(100);
            entity.Property(p => p.Description).HasMaxLength(200);
            entity.HasIndex(p => p.Name).IsUnique();
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable(Tables.Identity.RefreshTokens, Schemas.Identity);
            entity.HasKey(t => t.Id);
            entity.Property(t => t.TokenHash).IsRequired().HasMaxLength(128);
            entity.HasIndex(t => t.TokenHash).IsUnique();
            entity.HasIndex(t => t.UserId);
            entity.HasIndex(t => t.FamilyId);
            entity.Property(t => t.DeviceLabel).HasMaxLength(120);
            entity.Property(t => t.UserAgent).HasMaxLength(400);
            entity.Property(t => t.IpAddress).HasMaxLength(45);
        });

        modelBuilder.Entity<TwoFactorRecoveryCode>(entity =>
        {
            entity.ToTable(Tables.Identity.TwoFactorRecoveryCodes, Schemas.Identity);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Id).ValueGeneratedOnAdd();
            entity.Property(c => c.CodeHash).IsRequired().HasMaxLength(128);
            // Unique per user so a generated batch can never collide with an existing code,
            // which would otherwise make one code valid for two sign-ins.
            entity.HasIndex(c => new { c.TenantId, c.UserId, c.CodeHash }).IsUnique();
            entity.HasIndex(c => new { c.TenantId, c.UserId });
            entity.HasOne<User>().WithMany().HasForeignKey(c => c.UserId);
        });

        modelBuilder.Entity<TwoFactorChallenge>(entity =>
        {
            entity.ToTable(Tables.Identity.TwoFactorChallenges, Schemas.Identity);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Id).ValueGeneratedOnAdd();
            entity.Property(c => c.TokenHash).IsRequired().HasMaxLength(128);
            entity.HasIndex(c => c.TokenHash).IsUnique();
            entity.HasIndex(c => c.UserId);
            // Supports the periodic purge of spent and expired challenges.
            entity.HasIndex(c => new { c.ExpiresAt, c.ConsumedAt });
            entity.HasOne<User>().WithMany().HasForeignKey(c => c.UserId);
        });

        modelBuilder.Entity<EmailVerificationCode>(entity =>
        {
            entity.ToTable(Tables.Identity.EmailVerificationCodes, Schemas.Identity);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.CodeHash).IsRequired().HasMaxLength(128);
            entity.HasIndex(c => c.CodeHash).IsUnique();
            entity.HasIndex(c => new { c.TenantId, c.UserId });
        });

        modelBuilder.Entity<PasswordResetCode>(entity =>
        {
            entity.ToTable(Tables.Identity.PasswordResetCodes, Schemas.Identity);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.CodeHash).IsRequired().HasMaxLength(128);
            entity.HasIndex(c => new { c.TenantId, c.UserId });
        });

        modelBuilder.Entity<InvitationCode>(entity =>
        {
            entity.ToTable(Tables.Identity.InvitationCodes, Schemas.Identity);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.CodeHash).IsRequired().HasMaxLength(128);
            entity.HasIndex(c => c.CodeHash).IsUnique();
            entity.HasIndex(c => c.TenantId);
        });

        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.ToTable(Tables.Platform.AuditLogs, Schemas.Platform);
            entity.HasKey(a => a.Id);
            entity.Property(a => a.Action).IsRequired().HasMaxLength(100);
            entity.Property(a => a.EntityType).IsRequired().HasMaxLength(100);
            entity.Property(a => a.EntityId).HasMaxLength(64);
            entity.Property(a => a.Changes).HasColumnType("text");
            entity.Property(a => a.IpAddress).HasMaxLength(64);
            entity.HasIndex(a => new { a.TenantId, a.CreatedAt });
            entity.HasIndex(a => new { a.EntityType, a.EntityId });
        });

        modelBuilder.Entity<ProductCategory>(entity =>
        {
            entity.ToTable(Tables.Catalog.ProductCategories, Schemas.Catalog);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Name).IsRequired().HasMaxLength(100);
            entity.HasIndex(c => new { c.TenantId, c.Name }).IsUnique();
            entity.HasOne<ProductCategory>()
                .WithMany()
                .HasForeignKey(c => c.ParentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Brand>(entity =>
        {
            entity.ToTable(Tables.Catalog.Brands, Schemas.Catalog);
            entity.HasKey(b => b.Id);
            entity.Property(b => b.Name).IsRequired().HasMaxLength(200);
            entity.HasIndex(b => new { b.TenantId, b.Name });
        });

        modelBuilder.Entity<UnitOfMeasure>(entity =>
        {
            entity.ToTable(Tables.Catalog.UnitsOfMeasure, Schemas.Catalog);
            entity.HasKey(u => u.Id);
            entity.Property(u => u.Name).IsRequired().HasMaxLength(100);
            entity.Property(u => u.Abbreviation).IsRequired().HasMaxLength(10);
            entity.HasIndex(u => new { u.TenantId, u.Name }).IsUnique();
        });

        modelBuilder.Entity<Product>(entity =>
        {
            entity.ToTable(Tables.Catalog.Products, Schemas.Catalog);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Name).IsRequired().HasMaxLength(200);
            entity.Property(p => p.Description).HasColumnType("text");
            entity.Property(p => p.Sku).HasMaxLength(64);
            entity.Property(p => p.Barcode).HasMaxLength(64);
            entity.Property(p => p.ProductType).IsRequired();
            entity.Property(p => p.Status).IsRequired().HasDefaultValue(ProductStatus.Draft);
            entity.Property(p => p.CostPrice).HasColumnType("decimal(18,4)");
            entity.HasIndex(p => p.TenantId);
            entity.HasIndex(p => new { p.TenantId, p.Sku })
                .IsUnique()
                .HasFilter("\"Sku\" IS NOT NULL");
            entity.HasIndex(p => new { p.TenantId, p.Barcode })
                .IsUnique()
                .HasFilter("\"Barcode\" IS NOT NULL");
            entity.HasOne<ProductCategory>()
                .WithMany()
                .HasForeignKey(p => p.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Brand>()
                .WithMany()
                .HasForeignKey(p => p.BrandId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<UnitOfMeasure>()
                .WithMany()
                .HasForeignKey(p => p.UnitOfMeasureId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<TaxCategory>()
                .WithMany()
                .HasForeignKey(p => p.TaxCategoryId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(p => p.Variants)
                .WithOne()
                .HasForeignKey(v => v.ProductId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ProductVariant>(entity =>
        {
            entity.ToTable(Tables.Catalog.ProductVariants, Schemas.Catalog);
            entity.HasKey(v => v.Id);
            entity.Property(v => v.Id).ValueGeneratedOnAdd();
            entity.Property(v => v.Name).IsRequired().HasMaxLength(200);
            entity.Property(v => v.Sku).HasMaxLength(64);
            entity.Property(v => v.Barcode).HasMaxLength(64);
            entity.HasIndex(v => v.TenantId);
            entity.HasIndex(v => new { v.TenantId, v.Sku })
                .IsUnique()
                .HasFilter("\"Sku\" IS NOT NULL");
            entity.HasIndex(v => new { v.TenantId, v.Barcode })
                .IsUnique()
                .HasFilter("\"Barcode\" IS NOT NULL");
        });

        modelBuilder.Entity<Warehouse>(entity =>
        {
            entity.ToTable(Tables.Inventory.Warehouses, Schemas.Inventory);
            entity.HasKey(w => w.Id);
            entity.Property(w => w.Name).IsRequired().HasMaxLength(200);
            entity.Property(w => w.Code).IsRequired().HasMaxLength(50);
            entity.Property(w => w.Description).HasColumnType("text");
            entity.HasIndex(w => new { w.TenantId, w.Code }).IsUnique();
            entity.HasIndex(w => w.BranchId);
            entity.HasOne<Branch>()
                .WithMany()
                .HasForeignKey(w => w.BranchId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(w => w.Locations)
                .WithOne()
                .HasForeignKey(l => l.WarehouseId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<StockLocation>(entity =>
        {
            entity.ToTable(Tables.Inventory.StockLocations, Schemas.Inventory);
            entity.HasKey(l => l.Id);
            entity.Property(l => l.Id).ValueGeneratedOnAdd();
            entity.Property(l => l.Code).IsRequired().HasMaxLength(50);
            entity.Property(l => l.Name).IsRequired().HasMaxLength(200);
            entity.HasIndex(l => l.TenantId);
            entity.HasIndex(l => new { l.WarehouseId, l.Code }).IsUnique();
        });

        modelBuilder.Entity<StockBalance>(entity =>
        {
            entity.ToTable(Tables.Inventory.StockBalances, Schemas.Inventory);
            entity.HasKey(b => b.Id);
            entity.HasIndex(b => b.TenantId);
            entity.HasIndex(b => new { b.TenantId, b.WarehouseId, b.StockLocationId, b.ProductId, b.VariantId })
                .IsUnique();
            entity.HasOne<StockLocation>()
                .WithMany()
                .HasForeignKey(b => b.StockLocationId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(b => b.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(b => b.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockBatch>()
                .WithMany()
                .HasForeignKey(b => b.BatchId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<StockMovement>(entity =>
        {
            entity.ToTable(Tables.Inventory.StockMovements, Schemas.Inventory);
            entity.HasKey(m => m.Id);
            entity.Property(m => m.MovementType).IsRequired();
            entity.Property(m => m.ReferenceType).HasMaxLength(100);
            entity.Property(m => m.Reason).HasMaxLength(500);
            entity.Property(m => m.CorrelationId).HasMaxLength(64);
            entity.HasIndex(m => new { m.TenantId, m.ProductId, m.CreatedAt });
            entity.HasIndex(m => new { m.TenantId, m.WarehouseId, m.StockLocationId, m.ProductId, m.VariantId, m.OccurredAt });
            entity.HasOne<Warehouse>()
                .WithMany()
                .HasForeignKey(m => m.WarehouseId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockLocation>()
                .WithMany()
                .HasForeignKey(m => m.StockLocationId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(m => m.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(m => m.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<UnitOfMeasure>()
                .WithMany()
                .HasForeignKey(m => m.UnitOfMeasureId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockBatch>()
                .WithMany()
                .HasForeignKey(m => m.BatchId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Transfer>(entity =>
        {
            entity.ToTable(Tables.Inventory.Transfers, Schemas.Inventory);
            entity.HasKey(t => t.Id);
            entity.Property(t => t.ReferenceType).HasMaxLength(100);
            entity.Property(t => t.Reason).HasMaxLength(500);
            entity.Property(t => t.Status).IsRequired();
            entity.HasIndex(t => new { t.TenantId, t.SourceWarehouseId, t.DestinationWarehouseId });
            entity.HasIndex(t => t.TenantId);
            entity.HasOne<Warehouse>()
                .WithMany()
                .HasForeignKey(t => t.SourceWarehouseId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Warehouse>()
                .WithMany()
                .HasForeignKey(t => t.DestinationWarehouseId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockLocation>()
                .WithMany()
                .HasForeignKey(t => t.SourceLocationId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockLocation>()
                .WithMany()
                .HasForeignKey(t => t.DestinationLocationId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(t => t.Lines)
                .WithOne()
                .HasForeignKey(l => l.TransferId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<TransferLine>(entity =>
        {
            entity.ToTable(Tables.Inventory.TransferLines, Schemas.Inventory);
            entity.HasKey(l => l.Id);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(l => l.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(l => l.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockBatch>()
                .WithMany()
                .HasForeignKey(l => l.BatchId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<StockCount>(entity =>
        {
            entity.ToTable(Tables.Inventory.StockCounts, Schemas.Inventory);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Notes).HasMaxLength(500);
            entity.Property(c => c.Status).IsRequired();
            entity.HasIndex(c => c.TenantId);
            entity.HasIndex(c => new { c.TenantId, c.WarehouseId, c.ProductId });
            entity.HasOne<Warehouse>()
                .WithMany()
                .HasForeignKey(c => c.WarehouseId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<StockLocation>()
                .WithMany()
                .HasForeignKey(c => c.StockLocationId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(c => c.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(c => c.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<StockBatch>(entity =>
        {
            entity.ToTable(Tables.Inventory.StockBatches, Schemas.Inventory);
            entity.HasKey(b => b.Id);
            entity.Property(b => b.BatchNumber).IsRequired().HasMaxLength(100);
            entity.Property(b => b.Notes).HasMaxLength(500);
            entity.HasIndex(b => new { b.TenantId, b.ProductId, b.BatchNumber }).IsUnique();
            entity.HasIndex(b => b.TenantId);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(b => b.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(b => b.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<PriceList>(entity =>
        {
            entity.ToTable(Tables.Pricing.PriceLists, Schemas.Pricing);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Name).IsRequired().HasMaxLength(200);
            entity.Property(p => p.Currency).IsRequired().HasMaxLength(3);
            entity.HasIndex(p => new { p.TenantId, p.Name }).IsUnique();
            entity.HasIndex(p => p.TenantId)
                .IsUnique()
                .HasFilter("\"IsDefault\" = true");
            entity.HasMany(p => p.Prices)
                .WithOne()
                .HasForeignKey(p => p.PriceListId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ProductPrice>(entity =>
        {
            entity.ToTable(Tables.Pricing.ProductPrices, Schemas.Pricing);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Id).ValueGeneratedOnAdd();
            entity.Property(p => p.PriceType).IsRequired();
            entity.Property(p => p.Price).IsRequired();
            entity.Property(p => p.Currency).IsRequired().HasMaxLength(3);
            entity.Property(p => p.MinQuantity).IsRequired();
            entity.HasIndex(p => p.TenantId);
            entity.HasIndex(p => p.ProductId);
            entity.HasIndex(p => p.BranchId);
            entity.HasIndex(p => p.VariantId);
            entity.HasIndex(p => new { p.PriceListId, p.ProductId, p.VariantId, p.BranchId, p.PriceType })
                .IsUnique();
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(p => p.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(p => p.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Branch>()
                .WithMany()
                .HasForeignKey(p => p.BranchId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<FeatureFlag>(entity =>
        {
            entity.ToTable(Tables.Platform.FeatureFlags, Schemas.Platform);
            entity.HasKey(f => f.Id);
            entity.Property(f => f.Key).IsRequired().HasMaxLength(100);
            entity.Property(f => f.Config).HasColumnType("jsonb");
            entity.HasIndex(f => new { f.TenantId, f.Key }).IsUnique();
        });

        modelBuilder.Entity<OutboxMessage>(entity =>
        {
            entity.ToTable(Tables.Platform.OutboxMessages, Schemas.Platform);
            entity.HasKey(o => o.Id);
            entity.Property(o => o.Type).IsRequired().HasMaxLength(500);
            entity.Property(o => o.Payload).IsRequired().HasColumnType("jsonb");
            entity.HasIndex(o => new { o.ProcessedAt, o.OccurredAt });
        });

        modelBuilder.Entity<TaxCategory>(entity =>
        {
            entity.ToTable(Tables.Sales.TaxCategories, Schemas.Sales);
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Code).IsRequired().HasMaxLength(50);
            entity.Property(c => c.Name).IsRequired().HasMaxLength(200);
            entity.HasIndex(c => c.Code).IsUnique();
        });

        modelBuilder.Entity<TaxRegime>(entity =>
        {
            entity.ToTable(Tables.Sales.TaxRegimes, Schemas.Sales);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.Code).IsRequired().HasMaxLength(50);
            entity.Property(r => r.Name).IsRequired().HasMaxLength(200);
            entity.Property(r => r.CountryCode).IsRequired().HasMaxLength(2);
            entity.HasIndex(r => r.Code).IsUnique();
        });

        modelBuilder.Entity<TaxRule>(entity =>
        {
            entity.ToTable(Tables.Sales.TaxRules, Schemas.Sales);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.Code).IsRequired().HasMaxLength(50);
            entity.Property(r => r.Rate).IsRequired().HasColumnType("decimal(18,4)");
            entity.Property(r => r.CalculationStrategyKey).HasMaxLength(100);
            entity.HasIndex(r => new { r.RegimeId, r.CategoryId, r.Code, r.EffectiveFrom }).IsUnique();
            entity.HasOne<TaxRegime>()
                .WithMany()
                .HasForeignKey(r => r.RegimeId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<TaxCategory>()
                .WithMany()
                .HasForeignKey(r => r.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<TaxExemption>(entity =>
        {
            entity.ToTable(Tables.Sales.TaxExemptions, Schemas.Sales);
            entity.HasKey(e => e.Id);
            entity.Property(e => e.TransactionType).HasMaxLength(50);
            entity.HasIndex(e => new { e.TenantId, e.CategoryId });
            entity.HasOne<Tenant>()
                .WithMany()
                .HasForeignKey(e => e.TenantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<TaxCategory>()
                .WithMany()
                .HasForeignKey(e => e.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Sale>(entity =>
        {
            entity.ToTable(Tables.Sales.SalesTable, Schemas.Sales);
            entity.HasKey(s => s.Id);
            entity.Property(s => s.Number).IsRequired().HasMaxLength(50);
            entity.Property(s => s.Currency).IsRequired().HasMaxLength(3);
            entity.Property(s => s.CustomerName).HasMaxLength(200);
            entity.Property(s => s.CustomerTin).HasMaxLength(100);
            entity.Property(s => s.VoidReason).HasMaxLength(500);
            entity.Property(s => s.BuyerTin).HasMaxLength(100);
            entity.Property(s => s.BuyerName).HasMaxLength(200);
            entity.Property(s => s.BuyerIdType).HasMaxLength(50);
            entity.Property(s => s.BuyerMobile).HasMaxLength(50);
            entity.Property(s => s.FiscalReceiptNumber).HasMaxLength(100);
            entity.Property(s => s.FiscalVerificationCode).HasMaxLength(100);
            entity.Property(s => s.FiscalZNumber).HasMaxLength(50);
            entity.HasIndex(s => new { s.TenantId, s.ClientSaleId }).IsUnique();
            entity.HasIndex(s => new { s.TenantId, s.Number })
                .IsUnique()
                .HasFilter("\"Number\" IS NOT NULL");
            entity.HasIndex(s => new { s.TenantId, s.BranchId, s.SaleDate });
            entity.HasMany(s => s.Lines)
                .WithOne()
                .HasForeignKey(l => l.SaleId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(s => s.Payments)
                .WithOne()
                .HasForeignKey(p => p.SaleId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SaleLine>(entity =>
        {
            entity.ToTable(Tables.Sales.SaleLines, Schemas.Sales);
            entity.HasKey(l => l.Id);
            entity.Property(l => l.ProductName).IsRequired().HasMaxLength(200);
            entity.Property(l => l.Sku).HasMaxLength(64);
            entity.Property(l => l.Barcode).HasMaxLength(64);
            entity.Property(l => l.UnitOfMeasureName).HasMaxLength(100);
            entity.Property(l => l.UnitCost).HasColumnType("decimal(18,4)");
            entity.Property(l => l.TaxCode).IsRequired().HasMaxLength(50);
            entity.Property(l => l.AppliedRate).HasColumnType("decimal(18,4)");
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(l => l.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ProductVariant>()
                .WithMany()
                .HasForeignKey(l => l.VariantId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<UnitOfMeasure>()
                .WithMany()
                .HasForeignKey(l => l.UnitOfMeasureId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<SalePayment>(entity =>
        {
            entity.ToTable(Tables.Sales.SalePayments, Schemas.Sales);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Provider).HasMaxLength(100);
            entity.Property(p => p.PhoneNumber).HasMaxLength(50);
            entity.Property(p => p.Reference).HasMaxLength(200);
        });

        modelBuilder.Entity<NumberSequence>(entity =>
        {
            entity.ToTable(Tables.Sales.NumberSequences, Schemas.Sales);
            entity.HasKey(n => n.Id);
            entity.Property(n => n.Scope).IsRequired().HasMaxLength(100);
            entity.Property(n => n.Prefix).IsRequired().HasMaxLength(50);
            entity.Property(n => n.Pattern).IsRequired().HasMaxLength(200);
            entity.HasIndex(n => new { n.TenantId, n.Scope }).IsUnique();
            entity.HasOne<Tenant>()
                .WithMany()
                .HasForeignKey(n => n.TenantId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ReceiptLayout>(entity =>
        {
            entity.ToTable(Tables.Sales.ReceiptLayouts, Schemas.Sales);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.LayoutId).IsRequired().HasMaxLength(100);
            entity.Property(r => r.PaperWidth).IsRequired().HasMaxLength(20);
            entity.Property(r => r.PaperHeight).HasMaxLength(20);
            entity.Property(r => r.Sections).HasColumnType("jsonb").IsRequired();
            entity.Property(r => r.Styling).HasColumnType("jsonb");
            entity.HasIndex(r => new { r.TenantId, r.LayoutId, r.Version }).IsUnique();
            entity.HasIndex(r => new { r.TenantId, r.LayoutId, r.IsActive })
                .HasFilter("\"IsActive\" = true");
            entity.HasOne<Tenant>()
                .WithMany()
                .HasForeignKey(r => r.TenantId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ReceiptMetadata>(entity =>
        {
            entity.ToTable(Tables.Sales.ReceiptMetadata, Schemas.Sales);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.BusinessIdentitySnapshot).IsRequired().HasColumnType("jsonb");
            entity.Property(r => r.FiscalHash).HasMaxLength(512);
            entity.Property(r => r.FiscalSignatureAlgorithm).HasMaxLength(50);
            entity.Property(r => r.CanonicalPayloadHash).HasMaxLength(512);
            entity.HasIndex(r => r.SaleId).IsUnique();
            entity.HasOne<Sale>()
                .WithMany()
                .HasForeignKey(r => r.SaleId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ReceiptLayout>()
                .WithMany()
                .HasForeignKey(r => r.LayoutVersionId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ReceiptPrintEvent>(entity =>
        {
            entity.ToTable(Tables.Sales.ReceiptPrintEvents, Schemas.Sales);
            entity.HasKey(r => r.Id);
            entity.Property(r => r.DeviceId).HasMaxLength(100);
            entity.Property(r => r.Notes).HasColumnType("text");
            entity.HasIndex(r => new { r.SaleId, r.PrintedAt });
            entity.HasIndex(r => new { r.TenantId, r.PrintedAt });
            entity.HasOne<Sale>()
                .WithMany()
                .HasForeignKey(r => r.SaleId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<Tenant>()
                .WithMany()
                .HasForeignKey(r => r.TenantId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Supplier>(entity =>
        {
            entity.ToTable(Tables.Purchasing.Suppliers, Schemas.Purchasing);
            entity.HasKey(s => s.Id);
            entity.Property(s => s.Name).IsRequired().HasMaxLength(200);
            entity.Property(s => s.ContactName).HasMaxLength(200);
            entity.Property(s => s.Email).HasMaxLength(320);
            entity.Property(s => s.Phone).HasMaxLength(50);
            entity.Property(s => s.Address).HasColumnType("text");
            entity.Property(s => s.Tin).HasMaxLength(64);
            entity.Property(s => s.Notes).HasMaxLength(500);
            entity.HasIndex(s => new { s.TenantId, s.Name }).IsUnique();
        });

        modelBuilder.Entity<PurchaseOrder>(entity =>
        {
            entity.ToTable(Tables.Purchasing.PurchaseOrders, Schemas.Purchasing);
            entity.HasKey(o => o.Id);
            entity.Property(o => o.Reference).HasMaxLength(100);
            entity.Property(o => o.Notes).HasMaxLength(500);
            entity.Property(o => o.Status).IsRequired();
            entity.HasIndex(o => new { o.TenantId, o.SupplierId });
            entity.HasIndex(o => o.TenantId);
            entity.HasOne<Supplier>()
                .WithMany()
                .HasForeignKey(o => o.SupplierId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Warehouse>()
                .WithMany()
                .HasForeignKey(o => o.WarehouseId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(o => o.Lines)
                .WithOne()
                .HasForeignKey(l => l.PurchaseOrderId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PurchaseOrderLine>(entity =>
        {
            entity.ToTable(Tables.Purchasing.PurchaseOrderLines, Schemas.Purchasing);
            entity.HasKey(l => l.Id);
            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(l => l.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<SupplierBill>(entity =>
        {
            entity.ToTable(Tables.Purchasing.SupplierBills, Schemas.Purchasing);
            entity.HasKey(b => b.Id);
            entity.Property(b => b.BillNumber).HasMaxLength(100);
            entity.Property(b => b.Notes).HasMaxLength(500);
            entity.Property(b => b.Status).IsRequired();
            entity.HasIndex(b => new { b.TenantId, b.PurchaseOrderId }).IsUnique();
            entity.HasIndex(b => b.TenantId);
            entity.HasOne<Supplier>()
                .WithMany()
                .HasForeignKey(b => b.SupplierId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<PurchaseOrder>()
                .WithMany()
                .HasForeignKey(b => b.PurchaseOrderId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<SupplierPayment>(entity =>
        {
            entity.ToTable(Tables.Purchasing.SupplierPayments, Schemas.Purchasing);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Provider).HasMaxLength(100);
            entity.Property(p => p.PhoneNumber).HasMaxLength(50);
            entity.Property(p => p.Reference).HasMaxLength(200);
            entity.HasIndex(p => p.SupplierBillId);
            entity.HasOne<SupplierBill>()
                .WithMany()
                .HasForeignKey(p => p.SupplierBillId)
                .OnDelete(DeleteBehavior.Cascade);
        });

            modelBuilder.Entity<Account>(entity =>
            {
                entity.ToTable(Tables.Accounting.Accounts, Schemas.Accounting);
                entity.HasKey(a => a.Id);
                entity.Property(a => a.Code).IsRequired().HasMaxLength(50);
                entity.Property(a => a.Name).IsRequired().HasMaxLength(200);
                entity.HasIndex(a => new { a.TenantId, a.Code }).IsUnique();
                entity.HasIndex(a => a.TenantId);
            });

            modelBuilder.Entity<JournalEntry>(entity =>
            {
                entity.ToTable(Tables.Accounting.JournalEntries, Schemas.Accounting);
                entity.HasKey(j => j.Id);
                entity.Property(j => j.Description).IsRequired().HasMaxLength(500);
                entity.Property(j => j.SourceType).HasMaxLength(100);
                entity.HasIndex(j => j.TenantId);
                entity.HasIndex(j => new { j.TenantId, j.EntryDate });
                entity.HasIndex(j => new { j.SourceType, j.SourceId });
                entity.HasMany(j => j.Lines)
                    .WithOne()
                    .HasForeignKey(l => l.JournalEntryId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<JournalEntryLine>(entity =>
            {
                entity.ToTable(Tables.Accounting.JournalEntryLines, Schemas.Accounting);
                entity.HasKey(l => l.Id);
                entity.HasIndex(l => l.JournalEntryId);
                entity.HasIndex(l => l.AccountId);
                entity.HasOne<Account>()
                    .WithMany()
                    .HasForeignKey(l => l.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<TenantAccountMapping>(entity =>
            {
                entity.ToTable(Tables.Accounting.TenantAccountMappings, Schemas.Accounting);
                entity.HasKey(m => m.Id);
                entity.Property(m => m.MappingKey).IsRequired().HasMaxLength(100);
                entity.HasIndex(m => m.TenantId);
                entity.HasIndex(m => new { m.TenantId, m.MappingKey }).IsUnique();
                entity.HasIndex(m => m.AccountId);
                entity.HasOne<Account>()
                    .WithMany()
                    .HasForeignKey(m => m.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<Expense>(entity =>
            {
                entity.ToTable(Tables.Accounting.Expenses, Schemas.Accounting);
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Description).IsRequired().HasMaxLength(500);
                entity.Property(e => e.Amount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(e => e.PaymentMethod).HasMaxLength(100);
                entity.Property(e => e.Reference).HasMaxLength(200);
                entity.HasIndex(e => e.TenantId);
                entity.HasIndex(e => new { e.TenantId, e.ExpenseDate });
                entity.HasOne<ExpenseCategory>()
                    .WithMany()
                    .HasForeignKey(e => e.CategoryId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<ExpenseCategory>(entity =>
            {
                entity.ToTable(Tables.Accounting.ExpenseCategories, Schemas.Accounting);
                entity.HasKey(c => c.Id);
                entity.Property(c => c.Name).IsRequired().HasMaxLength(50);
                entity.HasIndex(c => c.TenantId);
                entity.HasIndex(c => new { c.TenantId, c.Name }).IsUnique();
            });

            modelBuilder.Entity<Customer>(entity =>
            {
                entity.ToTable(Tables.Crm.Customers, Schemas.Crm);
                entity.HasKey(c => c.Id);
                entity.Property(c => c.Name).IsRequired().HasMaxLength(200);
                entity.Property(c => c.ContactName).HasMaxLength(200);
                entity.Property(c => c.Email).HasMaxLength(320);
                entity.Property(c => c.Phone).HasMaxLength(30);
                entity.Property(c => c.Address).HasColumnType("text");
                entity.Property(c => c.Tin).HasMaxLength(64);
                entity.HasIndex(c => c.TenantId);
                entity.HasIndex(c => new { c.TenantId, c.Name });
            });

            modelBuilder.Entity<CustomerCredit>(entity =>
            {
                entity.ToTable(Tables.Crm.CustomerCredits, Schemas.Crm);
                entity.HasKey(c => c.Id);
                entity.Property(c => c.Balance).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(c => c.CreditLimit).IsRequired().HasColumnType("decimal(18,2)");
                entity.HasIndex(c => c.TenantId);
                entity.HasIndex(c => new { c.TenantId, c.CustomerId }).IsUnique();
            });

            modelBuilder.Entity<CreditTransaction>(entity =>
            {
                entity.ToTable(Tables.Crm.CreditTransactions, Schemas.Crm);
                entity.HasKey(t => t.Id);
                entity.Property(t => t.Type).IsRequired();
                entity.Property(t => t.Amount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(t => t.BalanceAfter).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(t => t.Description).IsRequired().HasMaxLength(500);
                entity.HasIndex(t => t.TenantId);
                entity.HasIndex(t => new { t.TenantId, t.CustomerId });
            });

            modelBuilder.Entity<MoneyAccount>(entity =>
            {
                entity.ToTable(Tables.Finance.MoneyAccounts, Schemas.Finance);
                entity.HasKey(a => a.Id);
                entity.Property(a => a.Name).IsRequired().HasMaxLength(200);
                entity.Property(a => a.Type).IsRequired();
                entity.Property(a => a.Reference).HasMaxLength(200);
                entity.Property(a => a.Balance).IsRequired().HasColumnType("decimal(18,2)");
                entity.HasIndex(a => a.TenantId);
                entity.HasIndex(a => new { a.TenantId, a.Name });
            });

            modelBuilder.Entity<MoneyAccountTransaction>(entity =>
            {
                entity.ToTable(Tables.Finance.MoneyAccountTransactions, Schemas.Finance);
                entity.HasKey(t => t.Id);
                entity.Property(t => t.Type).IsRequired();
                entity.Property(t => t.Amount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(t => t.BalanceAfter).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(t => t.Description).IsRequired().HasMaxLength(500);
                entity.Property(t => t.Reference).HasMaxLength(200);
                entity.HasIndex(t => t.TenantId);
                entity.HasIndex(t => new { t.TenantId, t.AccountId });
            });

            modelBuilder.Entity<CashSession>(entity =>
            {
                entity.ToTable(Tables.Finance.CashSessions, Schemas.Finance);
                entity.HasKey(s => s.Id);
                entity.Property(s => s.OpeningCash).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(s => s.ClosingCash).HasColumnType("decimal(18,2)");
                entity.Property(s => s.ExpectedCash).HasColumnType("decimal(18,2)");
                entity.Property(s => s.Variance).HasColumnType("decimal(18,2)");
                entity.Property(s => s.Status).IsRequired();
                entity.HasIndex(s => s.TenantId);
                entity.HasIndex(s => new { s.TenantId, s.AccountId });
            });

            modelBuilder.Entity<Plan>(entity =>
            {
                entity.ToTable(Tables.Billing.Plans, Schemas.Billing);
                entity.HasKey(p => p.Id);
                entity.Property(p => p.Code).IsRequired().HasMaxLength(50);
                entity.Property(p => p.Name).IsRequired().HasMaxLength(200);
                entity.Property(p => p.MonthlyPrice).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(p => p.Currency).IsRequired().HasMaxLength(3);
                entity.Property(p => p.FeatureKeys).HasColumnType("jsonb");
                entity.HasIndex(p => p.Code).IsUnique();
            });

            modelBuilder.Entity<Subscription>(entity =>
            {
                entity.ToTable(Tables.Billing.Subscriptions, Schemas.Billing);
                entity.HasKey(s => s.Id);
                entity.Property(s => s.PlanCode).IsRequired().HasMaxLength(50);
                entity.Property(s => s.Status).IsRequired();
                entity.Property(s => s.TrialEndedAtUtc).IsRequired();
                entity.HasIndex(s => s.TenantId).IsUnique();
            });

            modelBuilder.Entity<SubscriptionItem>(entity =>
            {
                entity.ToTable(Tables.Billing.SubscriptionItems, Schemas.Billing);
                entity.HasKey(s => s.Id);
                entity.Property(s => s.PlanCode).IsRequired().HasMaxLength(50);
                entity.HasIndex(s => s.TenantId);
                entity.HasIndex(s => new { s.TenantId, s.PlanCode }).IsUnique();
            });

            modelBuilder.Entity<Voucher>(entity =>
            {
                entity.ToTable(Tables.Billing.Vouchers, Schemas.Billing);
                entity.HasKey(v => v.Id);
                entity.Property(v => v.Code).IsRequired().HasMaxLength(50);
                entity.Property(v => v.ValueDays).IsRequired();
                entity.Property(v => v.Status).IsRequired();
                entity.HasIndex(v => v.Code).IsUnique();
                entity.HasIndex(v => v.RedeemedByTenantId);
                entity.HasIndex(v => v.ExpiresAtUtc);
            });

            modelBuilder.Entity<Invoice>(entity =>
            {
                entity.ToTable(Tables.Billing.Invoices, Schemas.Billing);
                entity.HasKey(i => i.Id);
                entity.Property(i => i.Number).IsRequired().HasMaxLength(50);
                entity.Property(i => i.Description).IsRequired().HasMaxLength(500);
                entity.Property(i => i.Amount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(i => i.Currency).IsRequired().HasMaxLength(3);
                entity.Property(i => i.Status).IsRequired();
                entity.Property(i => i.Reference).HasMaxLength(100);
                entity.HasIndex(i => i.TenantId);
                entity.HasIndex(i => new { i.TenantId, i.Status });
                entity.HasIndex(i => i.Number).IsUnique();
            });

            modelBuilder.Entity<CustomerInvoice>(entity =>
            {
                entity.ToTable(Tables.Invoicing.CustomerInvoices, Schemas.Invoicing);
                entity.HasKey(i => i.Id);
                entity.Property(i => i.Number).IsRequired().HasMaxLength(50);
                entity.Property(i => i.CustomerName).HasMaxLength(200);
                entity.Property(i => i.Currency).IsRequired().HasMaxLength(3);
                entity.Property(i => i.Status).IsRequired();
                entity.Property(i => i.Subtotal).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(i => i.TaxAmount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(i => i.TotalAmount).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(i => i.AmountPaid).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(i => i.PaymentMethod).HasMaxLength(50);
                entity.Property(i => i.PaymentReference).HasMaxLength(100);
                entity.Property(i => i.Notes).HasColumnType("text");
                entity.HasIndex(i => i.TenantId);
                entity.HasIndex(i => new { i.TenantId, i.Status });
                entity.HasIndex(i => new { i.TenantId, i.Number }).IsUnique();
                entity.HasMany(i => i.Lines)
                    .WithOne()
                    .HasForeignKey(l => l.CustomerInvoiceId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<CustomerInvoiceLine>(entity =>
            {
                entity.ToTable(Tables.Invoicing.CustomerInvoiceLines, Schemas.Invoicing);
                entity.HasKey(l => l.Id);
                entity.Property(l => l.Description).IsRequired().HasMaxLength(500);
                entity.Property(l => l.Quantity).IsRequired().HasColumnType("decimal(18,4)");
                entity.Property(l => l.UnitPrice).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(l => l.TaxRatePercent).IsRequired().HasColumnType("decimal(9,4)");
                entity.Property(l => l.LineTotal).IsRequired().HasColumnType("decimal(18,2)");
                entity.Property(l => l.TaxAmount).IsRequired().HasColumnType("decimal(18,2)");
                entity.HasIndex(l => l.CustomerInvoiceId);
            });

        modelBuilder.Entity<AppNotification>(entity =>
        {
            entity.ToTable(Tables.Notifications.NotificationsTable, Schemas.Notifications);
            entity.HasKey(n => n.Id);
            entity.Property(n => n.TenantId).IsRequired();
            entity.Property(n => n.Category).IsRequired().HasMaxLength(50);
            entity.Property(n => n.Type).IsRequired().HasMaxLength(100);
            entity.Property(n => n.TitleSw).IsRequired().HasMaxLength(255);
            entity.Property(n => n.TitleEn).IsRequired().HasMaxLength(255);
            entity.Property(n => n.BodySw).IsRequired().HasMaxLength(1000);
            entity.Property(n => n.BodyEn).IsRequired().HasMaxLength(1000);
            entity.Property(n => n.TargetRole).HasMaxLength(50);
            entity.Property(n => n.DataJson).HasColumnType("text");
            entity.Property(n => n.IsRead).IsRequired();
            entity.HasIndex(n => new { n.TenantId, n.UserId, n.CreatedAt });
            entity.HasIndex(n => new { n.TenantId, n.UserId, n.IsRead });
        });

        modelBuilder.Entity<UserDevice>(entity =>
        {
            entity.ToTable(Tables.Notifications.UserDevices, Schemas.Notifications);
            entity.HasKey(d => d.Id);
            entity.Property(d => d.TenantId).IsRequired();
            entity.Property(d => d.UserId).IsRequired();
            entity.Property(d => d.DeviceId).IsRequired().HasMaxLength(100);
            entity.Property(d => d.FcmToken).IsRequired().HasMaxLength(500);
            entity.Property(d => d.Platform).IsRequired().HasMaxLength(20);
            entity.Property(d => d.DeviceName).HasMaxLength(100);
            entity.Property(d => d.IsActive).IsRequired();
            entity.HasIndex(d => new { d.TenantId, d.UserId, d.DeviceId }).IsUnique();
            entity.HasIndex(d => new { d.TenantId, d.UserId });
        });

        modelBuilder.Entity<NotificationPreference>(entity =>
        {
            entity.ToTable(Tables.Notifications.NotificationPreferences, Schemas.Notifications);
            entity.HasKey(p => p.Id);
            entity.Property(p => p.TenantId).IsRequired();
            entity.Property(p => p.HighSaleThreshold).IsRequired().HasColumnType("decimal(18,2)");
            entity.Property(p => p.NotifyCashShortage).IsRequired();
            entity.Property(p => p.NotifySaleVoided).IsRequired();
            entity.Property(p => p.NotifyLowStock).IsRequired();
            entity.Property(p => p.PushEnabled).IsRequired();
            entity.HasIndex(p => new { p.TenantId, p.UserId }).IsUnique();
        });
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        ApplyAuditColumns();
        return base.SaveChangesAsync(cancellationToken);
    }

    Task<IReadOnlyList<DispatchedEvent>> IUnitOfWork.SaveChangesAsync(CancellationToken cancellationToken)
        => SaveAndDispatchAsync(cancellationToken);

    public async Task MarkProcessedAsync(
        IReadOnlyCollection<Guid> outboxMessageIds,
        CancellationToken cancellationToken = default)
    {
        if (outboxMessageIds.Count == 0)
        {
            return;
        }

        var rows = await OutboxMessages
            .Where(o => outboxMessageIds.Contains(o.Id))
            .ToListAsync(cancellationToken);

        foreach (var row in rows)
        {
            row.ProcessedAt = DateTime.UtcNow;
        }

        await base.SaveChangesAsync(cancellationToken);
    }

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
        => await Database.BeginTransactionAsync(cancellationToken);

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        var transaction = Database.CurrentTransaction;
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        var transaction = Database.CurrentTransaction;
        if (transaction is not null)
        {
            await transaction.RollbackAsync(cancellationToken);
        }
    }

    private async Task<IReadOnlyList<DispatchedEvent>> SaveAndDispatchAsync(CancellationToken cancellationToken)
    {
        var pending = new List<DispatchedEvent>();

        foreach (var entry in ChangeTracker.Entries<AggregateRoot>().ToList())
        {
            var tenantId = entry.Entity.GetType().GetProperty("TenantId")?.GetValue(entry.Entity) as Guid?;
            foreach (var domainEvent in entry.Entity.DomainEvents)
            {
                var message = new OutboxMessage
                {
                    Id = Guid.NewGuid(),
                    TenantId = tenantId,
                    Type = domainEvent.GetType().FullName ?? domainEvent.GetType().Name,
                    Payload = JsonSerializer.Serialize(domainEvent, domainEvent.GetType()),
                    OccurredAt = domainEvent.OccurredAt,
                };
                OutboxMessages.Add(message);
                pending.Add(new DispatchedEvent(message.Id, domainEvent));
            }

            entry.Entity.ClearDomainEvents();
        }

        ApplyAuditColumns();
        await base.SaveChangesAsync(cancellationToken);
        return pending;
    }

    private void ApplyAuditColumns()
    {
        var now = DateTime.UtcNow;
        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                if (entry.Entity.CreatedAt == default)
                {
                    entry.Entity.CreatedAt = now;
                }
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = now;
            }
        }
    }
}
