using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
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
    public DbSet<PriceList> PriceLists => Set<PriceList>();
    public DbSet<ProductPrice> ProductPrices => Set<ProductPrice>();
    public DbSet<FeatureFlag> FeatureFlags => Set<FeatureFlag>();
    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();

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
            entity.HasIndex(u => u.Email).IsUnique();
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
            foreach (var domainEvent in entry.Entity.DomainEvents)
            {
                var message = new OutboxMessage
                {
                    Id = Guid.NewGuid(),
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
