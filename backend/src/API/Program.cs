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
    .AddPermissionEngine();

builder.Services.AddScoped<IAuditContextProvider, HttpAuditContextProvider>();

builder.Services
    .Configure<SecurityOptions>(builder.Configuration.GetSection(SecurityOptions.SectionName))
    .Configure<CorsOptions>(builder.Configuration.GetSection(CorsOptions.SectionName))
    .Configure<RateLimitingOptions>(builder.Configuration.GetSection(RateLimitingOptions.SectionName))
    .Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName))
    .Configure<SmsOptions>(builder.Configuration.GetSection(SmsOptions.SectionName))
    .Configure<StorageOptions>(builder.Configuration.GetSection(StorageOptions.SectionName))
    .Configure<PaymentsOptions>(builder.Configuration.GetSection(PaymentsOptions.SectionName))
    .Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"))
    .AddOptions<SecurityOptions>().Validate(s => s.MaxFailedLoginAttempts > 0, "MaxFailedLoginAttempts must be > 0.").ValidateOnStart();

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
    if (cors.AllowedOrigins.Length > 0)
    {
        options.AddDefaultPolicy(policy => policy
            .WithOrigins(cors.AllowedOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod());
    }
    else if (builder.Environment.IsDevelopment())
    {
        options.AddDefaultPolicy(policy => policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod());
    }
});

builder.Services.AddPlatformHealthChecks(builder.Configuration);

builder.Services
    .AddOpenApi()
    .AddSwaggerGen(c => OpenApiConfiguration.ConfigureSwagger(c, typeof(Program).Assembly));

var app = builder.Build();

app.UseMiddleware<CorrelationIdMiddleware>();
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
    };
});

app.UseRateLimiter();
app.UseCors();
app.UseHttpsRedirection();

app.UseAuthentication();
app.UseMiddleware<UserContextMiddleware>();
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

if (app.Environment.IsEnvironment("Development") || app.Environment.IsEnvironment("Testing"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<BusinessDbContext>();
    await db.Database.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<BusinessOS.Infrastructure.DatabaseSeeder>().SeedAsync();
}

await app.RunAsync();

public partial class Program;
