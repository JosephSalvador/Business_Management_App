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
    .Configure<PlatformAdminOptions>(builder.Configuration.GetSection(PlatformAdminOptions.SectionName))
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
app.MapPlatformAdminEndpoints();
app.MapAppVersionEndpoints();
app.MapPublicInvoiceVerificationEndpoints();

var schemaSelfHealingStatements = new (string sql, string description)[]
{
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""LogoBase64"" text;", "Tenants.LogoBase64"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""BankName"" character varying(150);", "Tenants.BankName"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""BankAccountName"" character varying(200);", "Tenants.BankAccountName"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""BankAccountNumber"" character varying(100);", "Tenants.BankAccountNumber"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""BankBranchOrSwift"" character varying(150);", "Tenants.BankBranchOrSwift"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""MobileMoneyDetails"" character varying(300);", "Tenants.MobileMoneyDetails"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""InvoiceTerms"" text;", "Tenants.InvoiceTerms"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""AuthorizedSignatoryName"" character varying(150);", "Tenants.AuthorizedSignatoryName"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""AuthorizedSignatoryTitle"" character varying(150);", "Tenants.AuthorizedSignatoryTitle"),
    (@"ALTER TABLE public.""Tenants"" ADD COLUMN IF NOT EXISTS ""PaymentAccountsJson"" text;", "Tenants.PaymentAccountsJson"),

    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""DocumentTitle"" character varying(50) DEFAULT 'INVOICE';", "CustomerInvoices.DocumentTitle"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""ReferenceNumber"" character varying(100);", "CustomerInvoices.ReferenceNumber"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""PaymentTerms"" character varying(100);", "CustomerInvoices.PaymentTerms"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""CustomerAttention"" character varying(200);", "CustomerInvoices.CustomerAttention"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""CustomerPhone"" character varying(50);", "CustomerInvoices.CustomerPhone"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""CustomerEmail"" character varying(320);", "CustomerInvoices.CustomerEmail"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""CustomerAddress"" text;", "CustomerInvoices.CustomerAddress"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""CustomerTin"" character varying(64);", "CustomerInvoices.CustomerTin"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""DiscountAmount"" numeric(18,2) DEFAULT 0;", "CustomerInvoices.DiscountAmount"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""PaymentInstructions"" text;", "CustomerInvoices.PaymentInstructions"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""AuthorizedSignatoryName"" character varying(150);", "CustomerInvoices.AuthorizedSignatoryName"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""AuthorizedSignatoryTitle"" character varying(150);", "CustomerInvoices.AuthorizedSignatoryTitle"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""PaymentsJson"" text;", "CustomerInvoices.PaymentsJson"),
    (@"ALTER TABLE public.""CustomerInvoices"" ADD COLUMN IF NOT EXISTS ""VerificationToken"" character varying(32);", "CustomerInvoices.VerificationToken"),
    (@"UPDATE public.""CustomerInvoices"" SET ""VerificationToken"" = SUBSTRING(REPLACE(""Id""::text, '-', ''), 1, 16) WHERE ""VerificationToken"" IS NULL;", "CustomerInvoices.BackfillVerificationToken"),
    (@"CREATE UNIQUE INDEX IF NOT EXISTS ""IX_CustomerInvoices_VerificationToken"" ON public.""CustomerInvoices"" (""VerificationToken"");", "Index IX_CustomerInvoices_VerificationToken"),

    (@"ALTER TABLE public.""CustomerInvoiceLines"" ADD COLUMN IF NOT EXISTS ""UnitOfMeasure"" character varying(50) DEFAULT 'Pcs';", "CustomerInvoiceLines.UnitOfMeasure"),
    (@"ALTER TABLE public.""CustomerInvoiceLines"" ADD COLUMN IF NOT EXISTS ""DiscountAmount"" numeric(18,2) DEFAULT 0;", "CustomerInvoiceLines.DiscountAmount"),
    (@"ALTER TABLE public.""CustomerInvoiceLines"" ADD COLUMN IF NOT EXISTS ""TenantId"" uuid;", "CustomerInvoiceLines.TenantId"),
    (@"UPDATE public.""CustomerInvoiceLines"" l SET ""TenantId"" = i.""TenantId"" FROM public.""CustomerInvoices"" i WHERE l.""CustomerInvoiceId"" = i.""Id"" AND l.""TenantId"" IS NULL;", "CustomerInvoiceLines.BackfillTenantId"),

    (@"CREATE INDEX IF NOT EXISTS ""IX_CustomerInvoices_TenantId_CreatedAt"" ON public.""CustomerInvoices"" (""TenantId"", ""CreatedAt"");", "Index IX_CustomerInvoices_TenantId_CreatedAt"),
    (@"CREATE INDEX IF NOT EXISTS ""IX_CustomerInvoiceLines_TenantId_CreatedAt"" ON public.""CustomerInvoiceLines"" (""TenantId"", ""CreatedAt"");", "Index IX_CustomerInvoiceLines_TenantId_CreatedAt"),

    (@"CREATE TABLE IF NOT EXISTS public.""DocumentTemplates"" (
        ""Id"" uuid NOT NULL PRIMARY KEY,
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
        ""UpdatedBy"" uuid
    );", "Table DocumentTemplates"),

    (@"CREATE TABLE IF NOT EXISTS public.""TenantDocumentConfigurations"" (
        ""Id"" uuid NOT NULL PRIMARY KEY,
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
        ""UpdatedBy"" uuid
    );", "Table TenantDocumentConfigurations"),

    (@"CREATE INDEX IF NOT EXISTS ""IX_DocumentTemplates_DocumentType_IsActive_DisplayOrder""
        ON public.""DocumentTemplates"" (""DocumentType"", ""IsActive"", ""DisplayOrder"");", "Index IX_DocumentTemplates_DocumentType"),

    (@"CREATE INDEX IF NOT EXISTS ""IX_TenantDocumentConfigurations_ActiveTemplateId""
        ON public.""TenantDocumentConfigurations"" (""ActiveTemplateId"");", "Index IX_TenantDocumentConfigurations_ActiveTemplateId"),

    (@"CREATE UNIQUE INDEX IF NOT EXISTS ""IX_TenantDocumentConfigurations_TenantId_DocumentType""
        ON public.""TenantDocumentConfigurations"" (""TenantId"", ""DocumentType"");", "Index IX_TenantDocumentConfigurations_TenantId_DocumentType"),

    (@"CREATE TABLE IF NOT EXISTS public.""DeliveryNotes"" (
        ""Id"" uuid NOT NULL PRIMARY KEY,
        ""TenantId"" uuid NOT NULL,
        ""Number"" character varying(50) NOT NULL,
        ""InvoiceId"" uuid,
        ""InvoiceNumber"" character varying(50),
        ""CustomerId"" uuid,
        ""CustomerName"" character varying(200),
        ""CustomerAttention"" character varying(200),
        ""CustomerPhone"" character varying(50),
        ""DeliveryAddress"" text,
        ""IssueDate"" timestamp with time zone NOT NULL,
        ""Status"" integer NOT NULL,
        ""VehicleNumber"" character varying(50),
        ""DriverName"" character varying(150),
        ""DriverPhone"" character varying(50),
        ""ReceivedByName"" character varying(150),
        ""Notes"" text,
        ""DispatchedAtUtc"" timestamp with time zone,
        ""DeliveredAtUtc"" timestamp with time zone,
        ""CancelledAtUtc"" timestamp with time zone,
        ""CreatedAt"" timestamp with time zone NOT NULL,
        ""CreatedBy"" uuid,
        ""UpdatedAt"" timestamp with time zone,
        ""UpdatedBy"" uuid
    );", "Table DeliveryNotes"),

    (@"CREATE TABLE IF NOT EXISTS public.""DeliveryNoteItems"" (
        ""Id"" uuid NOT NULL PRIMARY KEY,
        ""TenantId"" uuid NOT NULL,
        ""DeliveryNoteId"" uuid NOT NULL,
        ""ProductId"" uuid,
        ""Description"" character varying(500) NOT NULL,
        ""UnitOfMeasure"" character varying(50) NOT NULL,
        ""QuantityOrdered"" numeric(18,4) NOT NULL,
        ""QuantityDelivered"" numeric(18,4) NOT NULL,
        ""LineIndex"" integer NOT NULL,
        ""CreatedAt"" timestamp with time zone NOT NULL,
        ""CreatedBy"" uuid,
        ""UpdatedAt"" timestamp with time zone,
        ""UpdatedBy"" uuid
    );", "Table DeliveryNoteItems"),

    (@"CREATE INDEX IF NOT EXISTS ""IX_DeliveryNotes_TenantId_CreatedAt"" ON public.""DeliveryNotes"" (""TenantId"", ""CreatedAt"");", "Index IX_DeliveryNotes_TenantId_CreatedAt"),
    (@"CREATE INDEX IF NOT EXISTS ""IX_DeliveryNotes_TenantId_Status"" ON public.""DeliveryNotes"" (""TenantId"", ""Status"");", "Index IX_DeliveryNotes_TenantId_Status"),
    (@"CREATE UNIQUE INDEX IF NOT EXISTS ""IX_DeliveryNotes_TenantId_Number"" ON public.""DeliveryNotes"" (""TenantId"", ""Number"");", "Index IX_DeliveryNotes_TenantId_Number"),
    (@"CREATE INDEX IF NOT EXISTS ""IX_DeliveryNotes_TenantId_InvoiceId"" ON public.""DeliveryNotes"" (""TenantId"", ""InvoiceId"");", "Index IX_DeliveryNotes_TenantId_InvoiceId"),
    (@"CREATE INDEX IF NOT EXISTS ""IX_DeliveryNoteItems_DeliveryNoteId"" ON public.""DeliveryNoteItems"" (""DeliveryNoteId"");", "Index IX_DeliveryNoteItems_DeliveryNoteId"),
    (@"CREATE INDEX IF NOT EXISTS ""IX_DeliveryNoteItems_TenantId_CreatedAt"" ON public.""DeliveryNoteItems"" (""TenantId"", ""CreatedAt"");", "Index IX_DeliveryNoteItems_TenantId_CreatedAt"),

    (@"INSERT INTO ""__EFMigrationsHistory"" (""MigrationId"", ""ProductVersion"") VALUES ('20261029100000_AddCompleteInvoiceAndBrandingElements', '9.0.0') ON CONFLICT DO NOTHING;", "Migration 20261029100000"),
    (@"INSERT INTO ""__EFMigrationsHistory"" (""MigrationId"", ""ProductVersion"") VALUES ('20261031180000_AddDeliveryNotesAndDocumentIndexes', '9.0.0') ON CONFLICT DO NOTHING;", "Migration 20261031180000"),
    (@"INSERT INTO ""__EFMigrationsHistory"" (""MigrationId"", ""ProductVersion"") VALUES ('20261031190000_AddDocumentTemplatesAndTenantConfigurations', '9.0.0') ON CONFLICT DO NOTHING;", "Migration 20261031190000"),
    (@"INSERT INTO ""__EFMigrationsHistory"" (""MigrationId"", ""ProductVersion"") VALUES ('20261103130000_AddMultiplePaymentMethodsAndInvoicePayments', '9.0.0') ON CONFLICT DO NOTHING;", "Migration 20261103130000")
};

app.MapGet("/health/schema-check", async (BusinessDbContext db) =>
{
    var signatoryExists = await db.Database.SqlQueryRaw<int>(
        @"SELECT COUNT(*)::int AS ""Value"" FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'Tenants' AND column_name = 'AuthorizedSignatoryName'").FirstOrDefaultAsync();

    var deliveryNotesExists = await db.Database.SqlQueryRaw<int>(
        @"SELECT COUNT(*)::int AS ""Value"" FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DeliveryNotes'").FirstOrDefaultAsync();

    return Results.Ok(new
    {
        environment = app.Environment.EnvironmentName,
        authorizedSignatoryColumn = signatoryExists > 0 ? "Present" : "Missing",
        deliveryNotesTable = deliveryNotesExists > 0 ? "Present" : "Missing"
    });
}).AllowAnonymous();

app.MapPost("/health/schema-heal", async (BusinessDbContext db) =>
{
    var results = new List<string>();
    foreach (var (sql, desc) in schemaSelfHealingStatements)
    {
        try
        {
            await db.Database.ExecuteSqlRawAsync(sql);
            results.Add($"{desc}: OK");
        }
        catch (Exception ex)
        {
            results.Add($"{desc}: ERROR - {ex.Message}");
        }
    }
    return Results.Ok(results);
}).AllowAnonymous();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<BusinessDbContext>();
    if (await db.Database.CanConnectAsync())
    {
        try
        {
            await db.Database.ExecuteSqlRawAsync(
                @"CREATE TABLE IF NOT EXISTS ""__EFMigrationsHistory"" (
                    ""MigrationId"" character varying(150) NOT NULL,
                    ""ProductVersion"" character varying(32) NOT NULL,
                    CONSTRAINT ""PK___EFMigrationsHistory"" PRIMARY KEY (""MigrationId"")
                  );");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Startup Migration History Notice] {ex.Message}");
        }

        foreach (var (sql, desc) in schemaSelfHealingStatements)
        {
            try
            {
                await db.Database.ExecuteSqlRawAsync(sql);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Startup Schema Self-Healing Notice] {desc}: {ex.Message}");
            }
        }

        try
        {
            await db.Database.MigrateAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Startup MigrateAsync Warning] {ex.Message}");
        }

        try
        {
            var seeder = scope.ServiceProvider.GetRequiredService<BusinessOS.Infrastructure.DatabaseSeeder>();
            if (app.Environment.IsEnvironment("Development") || app.Environment.IsEnvironment("Testing"))
            {
                await seeder.SeedAsync();
            }
            else
            {
                await seeder.SeedAsync(cancellationToken: default, createDemoTenant: true);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Startup Seeding Warning] {ex.Message}");
        }
    }
}

await app.RunAsync();

public partial class Program;
