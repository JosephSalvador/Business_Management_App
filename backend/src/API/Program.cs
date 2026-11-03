using System.Threading.RateLimiting;
using Asp.Versioning;
using BusinessOS.Api.Auditing;
using BusinessOS.Api.Endpoints;
using BusinessOS.Api.Exceptions;
using BusinessOS.Api.Health;
using BusinessOS.Api.Http;
using BusinessOS.Api.Middleware;
using BusinessOS.Api.OpenApi;
using BusinessOS.Application;
using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure;
using BusinessOS.Infrastructure.Authorization;
using BusinessOS.Infrastructure.Jobs;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Infrastructure.Security;
using BusinessOS.Infrastructure.Storage;
using BusinessOS.Localizations;
using BusinessOS.Notifications;
using BusinessOS.Shared.Configuration;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, services, configuration) => configuration
    .ReadFrom.Configuration(context.Configuration)
    .ReadFrom.Services(services)
    .Enrich.FromLogContext()
    .WriteTo.Console());

builder.Services.AddProblemDetails();

var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Jwt section is not configured.");

builder.Services
    .AddApplication()
    .AddInfrastructure(builder.Configuration)
    .AddNotificationEngine()
    .AddFileStorage(builder.Configuration)
    .AddJobQueue()
    .AddPermissionEngine()
    .AddLocalizations();

builder.Services.AddScoped<IAuditContextProvider, HttpAuditContextProvider>();

builder.Services
    .Configure<SecurityOptions>(builder.Configuration.GetSection(SecurityOptions.SectionName))
    .Configure<CorsOptions>(builder.Configuration.GetSection(CorsOptions.SectionName))
    .Configure<RateLimitingOptions>(builder.Configuration.GetSection(RateLimitingOptions.SectionName))
    .Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName))
    .Configure<SmsOptions>(builder.Configuration.GetSection(SmsOptions.SectionName))
    .Configure<StorageOptions>(builder.Configuration.GetSection(StorageOptions.SectionName))
    .Configure<PaymentsOptions>(builder.Configuration.GetSection(PaymentsOptions.SectionName))
    .Configure<TlsRiskOptions>(builder.Configuration.GetSection(TlsRiskOptions.SectionName))
    .Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));

builder.Services
    .AddOptions<JwtOptions>()
    .Validate(
        j => !string.IsNullOrWhiteSpace(j.Secret)
            && System.Text.Encoding.UTF8.GetByteCount(j.Secret) >= 32,
        "Jwt:Secret must be set and at least 32 bytes for HMAC-SHA256.")
    .ValidateOnStart();

builder.Services
    .AddOptions<SecurityOptions>()
    .Validate(s => s.MaxFailedLoginAttempts > 0, "MaxFailedLoginAttempts must be > 0.")
    .Validate(s => s.LockoutDurationMinutes > 0, "LockoutDurationMinutes must be > 0.")
    .Validate(
        s => s.TwoFactorChallengeMinutes is > 0 and <= 60,
        "TwoFactorChallengeMinutes must be between 1 and 60.")
    .Validate(
        s => s.TwoFactorStepSeconds is >= 15 and <= 120,
        "TwoFactorStepSeconds must be between 15 and 120 (RFC 6238 recommends 30).")
    .Validate(
        s => s.TwoFactorDigits is 6 or 8,
        "TwoFactorDigits must be 6 or 8; other widths are not supported by the client UI.")
    .Validate(
        s => s.TwoFactorWindow is >= 0 and <= 5,
        "TwoFactorWindow must be between 0 and 5 steps; wider windows weaken replay resistance.")
    .Validate(s => s.TwoFactorMaxAttempts > 0, "TwoFactorMaxAttempts must be > 0.")
    .Validate(
        s => s.TwoFactorRecoveryCodeCount is >= 1 and <= 20,
        "TwoFactorRecoveryCodeCount must be between 1 and 20.")
    .ValidateOnStart();

builder.Services.AddScoped<RequestContext>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(System.Text.Encoding.UTF8.GetBytes(jwt.Secret)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
            NameClaimType = System.Security.Claims.ClaimTypes.NameIdentifier,
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddMemoryCache();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await context.HttpContext.Response.WriteAsJsonAsync(new Microsoft.AspNetCore.Mvc.ProblemDetails
        {
            Title = "Too Many Requests",
            Status = StatusCodes.Status429TooManyRequests,
            Detail = "Rate limit exceeded. Please retry later.",
        }, cancellationToken);
    };

    options.AddPolicy("auth", httpContext =>
    {
        var authOptions = httpContext.RequestServices
            .GetRequiredService<IOptions<RateLimitingOptions>>().Value;
        return RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = authOptions.AuthPermitLimit,
                Window = TimeSpan.FromSeconds(authOptions.AuthWindowSeconds),
                QueueLimit = 0,
            });
    });

    options.AddPolicy("global", httpContext =>
    {
        var authOptions = httpContext.RequestServices
            .GetRequiredService<IOptions<RateLimitingOptions>>().Value;
        return RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = authOptions.GlobalPermitLimit,
                Window = TimeSpan.FromSeconds(authOptions.GlobalWindowSeconds),
                QueueLimit = 0,
            });
    });
});

builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = ApiVersionReader.Combine(new UrlSegmentApiVersionReader());
})
.AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddCors(options =>
{
    var cors = builder.Configuration.GetSection(CorsOptions.SectionName).Get<CorsOptions>() ?? new CorsOptions();
    options.AddDefaultPolicy(policy => policy
        .SetIsOriginAllowed(origin =>
        {
            if (cors.AllowedOrigins.Contains(origin)) return true;
            if (origin.EndsWith(".pages.dev", StringComparison.OrdinalIgnoreCase)) return true;
            if (origin.EndsWith(".joberthix.xyz", StringComparison.OrdinalIgnoreCase)) return true;
            if (origin.StartsWith("http://localhost:", StringComparison.OrdinalIgnoreCase) ||
                origin.StartsWith("https://localhost:", StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        })
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials());
});

builder.Services.AddPlatformHealthChecks(builder.Configuration);

builder.Services
    .AddOpenApi()
    .AddSwaggerGen(c => OpenApiConfiguration.ConfigureSwagger(c, typeof(Program).Assembly));

builder.Services.Configure<Microsoft.AspNetCore.Builder.ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor |
        Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

app.UseForwardedHeaders();
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<TlsFingerprintMiddleware>();
app.UseExceptionHandler();
app.UseSecurityHeaders();
app.UseSerilogRequestLogging(options =>
{
    options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
    {
        var context = httpContext.RequestServices.GetService<RequestContext>();
        diagnosticContext.Set("UserId", context?.UserId);
        diagnosticContext.Set("TenantId", context?.TenantId);
        diagnosticContext.Set("CorrelationId", context?.CorrelationId);
        diagnosticContext.Set("RemoteIp", context?.IpAddress);
        if (!string.IsNullOrEmpty(context?.TlsFingerprint))
        {
            diagnosticContext.Set("TlsFingerprint", context.TlsFingerprint);
        }
        if (context?.BotScore.HasValue == true)
        {
            diagnosticContext.Set("BotScore", context.BotScore.Value);
        }
    };
});

app.UseRateLimiter();
app.UseCors();
app.UseHttpsRedirection();

app.UseAuthentication();
app.UseMiddleware<UserContextMiddleware>();
app.UseMiddleware<TenantActiveMiddleware>();
app.UseMiddleware<SubscriptionAccessMiddleware>();
app.UseAuthorization();

if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Testing"))
{
    app.UseSwagger();
    app.UseSwaggerUI(options => OpenApiConfiguration.ConfigureSwaggerUi(options));
}

app.MapHealthChecks("/health");
app.MapPlatformHealthEndpoints();

app.MapAuthEndpoints();
app.MapOrganizationEndpoints();
app.MapIdentityEndpoints();
app.MapCatalogEndpoints();
app.MapReferenceDataEndpoints();
app.MapInventoryEndpoints();
app.MapPricingEndpoints();
app.MapDashboardEndpoints();
app.MapSalesEndpoints();
app.MapReceiptEndpoints();
app.MapPurchasingEndpoints();
app.MapAccountingEndpoints();
app.MapReportingEndpoints();
app.MapCustomerEndpoints();
app.MapCreditEndpoints();
app.MapFinanceEndpoints();
app.MapFeatureFlagEndpoints();
app.MapBillingEndpoints();
app.MapCapabilitiesEndpoints();
app.MapInvoiceEndpoints();
app.MapDeliveryNoteEndpoints();
app.MapDocumentTemplateEndpoints();
app.MapNotificationEndpoints();
app.MapTenantProvisioningEndpoints();
app.MapAppVersionEndpoints();

if (app.Environment.IsEnvironment("Development") || app.Environment.IsEnvironment("Testing"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<BusinessDbContext>();
    if (await db.Database.CanConnectAsync())
    {
        await db.Database.MigrateAsync();
        await scope.ServiceProvider.GetRequiredService<BusinessOS.Infrastructure.DatabaseSeeder>().SeedAsync();
    }
}
else if (app.Environment.IsEnvironment("LocalPreProduction") || app.Environment.IsProduction())
{
    // Pending migrations are applied here so preprod/production stays operable on managed DB hosts.
    // Only platform-level bootstrap data is seeded: the demo tenant and its known
    // dev credentials are never created outside Development/Testing.
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<BusinessDbContext>();

    try
    {
        // 1. Ensure __EFMigrationsHistory table exists
        await db.Database.ExecuteSqlRawAsync(
            @"CREATE TABLE IF NOT EXISTS ""__EFMigrationsHistory"" (
                ""MigrationId"" character varying(150) NOT NULL,
                ""ProductVersion"" character varying(32) NOT NULL,
                CONSTRAINT ""PK___EFMigrationsHistory"" PRIMARY KEY (""MigrationId"")
              );");

        // 2. Self-Healing: Purge any phantom entries in __EFMigrationsHistory where migrations
        // were prematurely marked as applied but the underlying tables were never created.
        var templatesExist = await db.Database.SqlQueryRaw<int>(
            @"SELECT COUNT(*)::int AS ""Value"" FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DocumentTemplates'").FirstOrDefaultAsync();

        if (templatesExist == 0)
        {
            await db.Database.ExecuteSqlRawAsync(
                @"DELETE FROM ""__EFMigrationsHistory"" WHERE ""MigrationId"" = '20261031190000_AddDocumentTemplatesAndTenantConfigurations';");
        }

        var deliveryNotesExist = await db.Database.SqlQueryRaw<int>(
            @"SELECT COUNT(*)::int AS ""Value"" FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DeliveryNotes'").FirstOrDefaultAsync();

        if (deliveryNotesExist == 0)
        {
            await db.Database.ExecuteSqlRawAsync(
                @"DELETE FROM ""__EFMigrationsHistory"" WHERE ""MigrationId"" = '20261031180000_AddDeliveryNotesAndDocumentIndexes';");
        }

        var paymentsJsonColExists = await db.Database.SqlQueryRaw<int>(
            @"SELECT COUNT(*)::int AS ""Value"" FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'CustomerInvoices' AND column_name = 'PaymentsJson'").FirstOrDefaultAsync();

        if (paymentsJsonColExists == 0)
        {
            await db.Database.ExecuteSqlRawAsync(
                @"DELETE FROM ""__EFMigrationsHistory"" WHERE ""MigrationId"" = '20261103130000_AddMultiplePaymentMethodsAndInvoicePayments';");
        }

        // 3. Fallback Idempotent DDL: Guarantee DocumentTemplates, TenantConfigurations, and Payment columns exist
        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS public.""DocumentTemplates"" (
                ""Id"" uuid NOT NULL,
                ""Name"" character varying(100) NOT NULL,
                ""Description"" character varying(500),
                ""DocumentType"" integer NOT NULL,
                ""LiquidLayout"" text NOT NULL,
                ""ThumbnailBase64"" text,
                ""EngineVersion"" character varying(50) NOT NULL,
                ""IsActive"" boolean NOT NULL,
                ""IsDefault"" boolean NOT NULL,
                ""DisplayOrder"" integer NOT NULL,
                ""CreatedAt"" timestamp with time zone NOT NULL,
                ""CreatedBy"" uuid,
                ""UpdatedAt"" timestamp with time zone,
                ""UpdatedBy"" uuid,
                CONSTRAINT ""PK_DocumentTemplates"" PRIMARY KEY (""Id"")
            );

            CREATE TABLE IF NOT EXISTS public.""TenantDocumentConfigurations"" (
                ""Id"" uuid NOT NULL,
                ""TenantId"" uuid NOT NULL,
                ""DocumentType"" integer NOT NULL,
                ""ActiveTemplateId"" uuid NOT NULL,
                ""CustomLiquidOverride"" text,
                ""ThemePrimaryHex"" character varying(20),
                ""ThemeSecondaryHex"" character varying(20),
                ""LogoUrl"" character varying(500),
                ""ShowLogo"" boolean NOT NULL,
                ""FooterNotes"" text,
                ""CreatedAt"" timestamp with time zone NOT NULL,
                ""CreatedBy"" uuid,
                ""UpdatedAt"" timestamp with time zone,
                ""UpdatedBy"" uuid,
                CONSTRAINT ""PK_TenantDocumentConfigurations"" PRIMARY KEY (""Id"")
            );

            CREATE INDEX IF NOT EXISTS ""IX_DocumentTemplates_DocumentType_IsActive_DisplayOrder""
                ON public.""DocumentTemplates"" (""DocumentType"", ""IsActive"", ""DisplayOrder"");

            CREATE INDEX IF NOT EXISTS ""IX_TenantDocumentConfigurations_ActiveTemplateId""
                ON public.""TenantDocumentConfigurations"" (""ActiveTemplateId"");

            CREATE UNIQUE INDEX IF NOT EXISTS ""IX_TenantDocumentConfigurations_TenantId_DocumentType""
                ON public.""TenantDocumentConfigurations"" (""TenantId"", ""DocumentType"");

            ALTER TABLE IF EXISTS public.""Tenants""
                ADD COLUMN IF NOT EXISTS ""PaymentAccountsJson"" text;

            ALTER TABLE IF EXISTS public.""CustomerInvoices""
                ADD COLUMN IF NOT EXISTS ""PaymentsJson"" text;
        ");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[Startup Migration Healing Warning] {ex.Message}");
    }

    await db.Database.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<BusinessOS.Infrastructure.DatabaseSeeder>()
        .SeedAsync(cancellationToken: default, createDemoTenant: true);
}

await app.RunAsync();

public partial class Program;
