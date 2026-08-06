using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
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
