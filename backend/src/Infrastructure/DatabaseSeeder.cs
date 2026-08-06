using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Infrastructure;

/// <summary>
/// Idempotent seed for local development: registers all known permissions and creates a
/// demo tenant + administrator user if they do not exist.
/// Dev credentials (never for production): admin@acme.local / Admin@12345
/// </summary>
public sealed class DatabaseSeeder
{
    private readonly BusinessDbContext _db;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(
        BusinessDbContext db,
        IPasswordHasher passwordHasher,
        ILogger<DatabaseSeeder> logger)
    {
        _db = db;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var existingNames = await _db.Permissions.Select(p => p.Name).ToListAsync(cancellationToken);
        var missing = PermissionNames.All.Where(name => !existingNames.Contains(name)).ToArray();

        foreach (var name in missing)
        {
            _db.Permissions.Add(Permission.Seed(name));
        }

        if (missing.Length > 0)
        {
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded {Count} permissions.", missing.Length);
        }

        var adminRoles = await _db.Roles
            .Include(r => r.Permissions)
            .Where(r => r.IsSystem && r.Name == "Administrator")
            .ToListAsync(cancellationToken);

        if (adminRoles.Count > 0)
        {
            var grantPermissions = await _db.Permissions
                .Where(p => PermissionNames.All.Contains(p.Name))
                .ToListAsync(cancellationToken);

            foreach (var role in adminRoles)
            {
                role.Grant(grantPermissions);
            }

            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Re-granted permissions to {Count} system administrator roles.", adminRoles.Count);
        }

        const string demoEmail = "admin@acme.local";
        var demoUser = await _db.Users.FirstOrDefaultAsync(u => u.Email == demoEmail, cancellationToken);
        if (demoUser is not null)
        {
            if (!await _db.Branches.AnyAsync(b => b.TenantId == demoUser.TenantId, cancellationToken))
            {
                _db.Branches.Add(Branch.Create(
                    demoUser.TenantId,
                    Branch.DefaultName,
                    Branch.DefaultCode,
                    Tenant.DefaultCurrency));
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Seeded default branch for the demo tenant.");
            }

            return;
        }

        var tenant = Tenant.Create(Guid.NewGuid(), "Acme Ltd");
        await _db.Tenants.AddAsync(tenant, cancellationToken);

        var adminRole = Role.Create(tenant.Id, "Administrator", isSystem: true);
        var allPermissions = await _db.Permissions
            .Where(p => PermissionNames.All.Contains(p.Name))
            .ToListAsync(cancellationToken);
        adminRole.Grant(allPermissions);
        await _db.Roles.AddAsync(adminRole, cancellationToken);

        var admin = User.Create(
            Guid.NewGuid(),
            tenant.Id,
            demoEmail,
            _passwordHasher.Hash("Admin@12345"),
            "System Administrator",
            phone: null);
        admin.AssignRole(adminRole);
        await _db.Users.AddAsync(admin, cancellationToken);

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Seeded demo tenant 'Acme Ltd' and administrator user.");
    }
}
