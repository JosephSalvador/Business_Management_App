using BusinessOS.Application.Features.Receipts.Services;
using BusinessOS.Application.Accounting;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Infrastructure.Caching;
using BusinessOS.Infrastructure.Events;
using BusinessOS.Infrastructure.Locking;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Infrastructure.Repositories;
using BusinessOS.Infrastructure.Persistence.Repositories;
using BusinessOS.Infrastructure.Security;
using BusinessOS.Shared.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddHttpContextAccessor();

        services.AddDbContext<BusinessDbContext>((serviceProvider, options) =>
        {
            var config = serviceProvider.GetRequiredService<IConfiguration>();
            var connectionString = config.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Connection string 'Default' is not configured.");
            options.UseNpgsql(connectionString);
        });

        services.AddScoped<IUnitOfWork>(sp => sp.GetRequiredService<BusinessDbContext>());
        services.AddScoped<ITenantRepository, TenantRepository>();
        services.AddScoped<IBranchRepository, BranchRepository>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRoleRepository, RoleRepository>();
        services.AddScoped<IPermissionRepository, PermissionRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<ITwoFactorRecoveryCodeRepository, TwoFactorRecoveryCodeRepository>();
        services.AddScoped<ITwoFactorChallengeRepository, TwoFactorChallengeRepository>();
        services.AddScoped<IEmailVerificationCodeRepository, EmailVerificationCodeRepository>();
        services.AddScoped<IPasswordResetCodeRepository, PasswordResetCodeRepository>();
        services.AddScoped<IInvitationCodeRepository, InvitationCodeRepository>();
        services.AddScoped<IAuditLogRepository, AuditLogRepository>();
        services.AddScoped<IFeatureFlagRepository, FeatureFlagRepository>();
        services.AddScoped<IProductRepository, ProductRepository>();
        services.AddScoped<ICategoryRepository, CategoryRepository>();
        services.AddScoped<IBrandRepository, BrandRepository>();
        services.AddScoped<IUnitOfMeasureRepository, UnitOfMeasureRepository>();
        services.AddScoped<IWarehouseRepository, WarehouseRepository>();
        services.AddScoped<IStockRepository, StockRepository>();
        services.AddScoped<IPriceListRepository, PriceListRepository>();
        services.AddScoped<IProductPriceRepository, ProductPriceRepository>();
        services.AddScoped<IDashboardRepository, DashboardRepository>();
        services.AddScoped<ITaxRuleRepository, TaxRuleRepository>();
        services.AddScoped<ISaleRepository, SaleRepository>();
        services.AddScoped<INumberSequenceRepository, NumberSequenceRepository>();
        services.AddScoped<ITransferRepository, TransferRepository>();
        services.AddScoped<IStockCountRepository, StockCountRepository>();
        services.AddScoped<IStockBatchRepository, StockBatchRepository>();
        services.AddScoped<ISupplierRepository, SupplierRepository>();
        services.AddScoped<IPurchaseOrderRepository, PurchaseOrderRepository>();
        services.AddScoped<ISupplierBillRepository, SupplierBillRepository>();
        services.AddScoped<ISupplierPaymentRepository, SupplierPaymentRepository>();
        services.AddScoped<IAccountRepository, AccountRepository>();
        services.AddScoped<IJournalEntryRepository, JournalEntryRepository>();
        services.AddScoped<ITenantAccountMappingRepository, TenantAccountMappingRepository>();
        services.AddScoped<IExpenseRepository, ExpenseRepository>();
        services.AddScoped<ICustomerRepository, CustomerRepository>();
        services.AddScoped<ICustomerCreditRepository, CustomerCreditRepository>();
        services.AddScoped<IMoneyAccountRepository, MoneyAccountRepository>();
        services.AddScoped<ICashSessionRepository, CashSessionRepository>();
        services.AddScoped<IReceiptLayoutRepository, ReceiptLayoutRepository>();
        services.AddScoped<IReceiptMetadataRepository, ReceiptMetadataRepository>();
        services.AddScoped<IReceiptPrintEventRepository, ReceiptPrintEventRepository>();
        services.AddScoped<IPlanRepository, PlanRepository>();
        services.AddScoped<ISubscriptionRepository, SubscriptionRepository>();
        services.AddScoped<ISubscriptionItemRepository, SubscriptionItemRepository>();
        services.AddScoped<IVoucherRepository, VoucherRepository>();
        services.AddScoped<IInvoiceRepository, InvoiceRepository>();
        services.AddScoped<ICustomerInvoiceRepository, CustomerInvoiceRepository>();
        services.AddScoped<IAppNotificationRepository, AppNotificationRepository>();
        services.AddScoped<IUserDeviceRepository, UserDeviceRepository>();
        services.AddScoped<INotificationPreferenceRepository, NotificationPreferenceRepository>();
        services.AddScoped<IAccountMappingService, AccountMappingService>();
        services.AddScoped<IReportRepository, ReportRepository>();
        services.AddSingleton<ICsvExportService, CsvExportService>();
        services.AddScoped<SaleStockDebitService>();
        services.AddScoped<IReceiptMetadataService, ReceiptMetadataService>();

        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<ITenantContext, HttpTenantContext>();
        services.AddScoped<IEventBus, InProcessEventBus>();
        services.AddScoped<ITenantAdvisoryLock, TenantAdvisoryLock>();
        services.AddScoped<DatabaseSeeder>();

        var jwtOptions = configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
        if (string.IsNullOrWhiteSpace(jwtOptions.Secret))
        {
            throw new InvalidOperationException("Jwt:Secret must be configured.");
        }

        if (jwtOptions.Secret.Length < 32)
        {
            throw new InvalidOperationException(
                "Jwt:Secret must be at least 32 characters. " +
                "Use a cryptographically random string (e.g., 64+ chars from a CSPRNG).");
        }

        services.AddSingleton(jwtOptions);
        services.AddSingleton<ITokenService, JwtTokenService>();

        services.AddSingleton<ITotpService, TotpService>();
        services.AddScoped<ISecretProtector>(sp => new AesSecretProtector(
            sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<SecurityOptions>>().Value,
            jwtOptions));

        var redisConnection = configuration.GetConnectionString("Redis");
        if (!string.IsNullOrWhiteSpace(redisConnection))
        {
            services.AddStackExchangeRedisCache(options =>
            {
                options.Configuration = redisConnection;
                options.InstanceName = "businessos:";
            });
            services.AddScoped<ICacheService, RedisCacheService>();
        }
        else
        {
            services.AddSingleton<ICacheService, InMemoryCacheService>();
        }

        return services;
    }
}
