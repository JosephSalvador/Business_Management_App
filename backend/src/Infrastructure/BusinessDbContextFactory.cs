using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace BusinessOS.Infrastructure;

/// <summary>
/// Design-time factory for `dotnet ef`. Reads the DATABASE_URL env var first,
/// then falls back to the local dev database. Production migrations never run here.
/// </summary>
public sealed class BusinessDbContextFactory : IDesignTimeDbContextFactory<BusinessDbContext>
{
    public BusinessDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("DATABASE_URL")
            ?? "Host=localhost;Port=5432;Database=businessos;Username=businessos;Password=Joseph662.";

        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(connectionString)
            .Options;

        return new BusinessDbContext(options);
    }
}
