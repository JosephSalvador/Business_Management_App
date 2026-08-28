using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace BusinessOS.Tests.Support;

public sealed class BusinessOsApiFactory : WebApplicationFactory<Program>
{
    public const string TestConnectionString =
        "Host=localhost;Port=5432;Database=businessos_test;Username=businessos;Password=Joseph662.";

    public const string TestJwtSecret =
        "test-secret-for-unit-tests-only-not-for-production-use-64-chars!";

    static BusinessOsApiFactory()
    {
        // Program.cs validates configuration during top-level statements, before
        // ConfigureAppConfiguration callbacks run, so secrets must be visible to the
        // standard environment-variable source (highest priority anyway).
        Environment.SetEnvironmentVariable("ConnectionStrings__Default", TestConnectionString);
        Environment.SetEnvironmentVariable("Jwt__Secret", TestJwtSecret);
        Environment.SetEnvironmentVariable("RateLimiting__AuthPermitLimit", "10000");
        Environment.SetEnvironmentVariable("RateLimiting__GlobalPermitLimit", "10000");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = TestConnectionString,
                ["Jwt:Secret"] = TestJwtSecret,
                ["RateLimiting:AuthPermitLimit"] = "10000",
                ["RateLimiting:GlobalPermitLimit"] = "10000",
            });
        });
    }
}
