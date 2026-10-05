using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Organizations.Commands;

/// <summary>
/// Completes the guided business setup. The creator and tenant come from the
/// authenticated principal — never from the request body.
/// </summary>
public sealed record CompleteOnboardingCommand(
    string Name,
    string? BusinessType,
    string CountryCode,
    string Currency,
    string? ContactPhone,
    string? TaxId) : IRequest<Result<WorkspaceDto>>, IRequiresTenantAdvisoryLock;

public sealed class CompleteOnboardingCommandHandler
    : IRequestHandler<CompleteOnboardingCommand, Result<WorkspaceDto>>
{
    public const string DefaultWarehouseName = "Main Store";
    public const string DefaultWarehouseCode = "MAINSTORE";
    public const string DefaultPriceListName = "Retail Prices";
    public static readonly string[] DefaultExpenseCategoryNames =
    [
        "Utilities", "Transport", "Rent", "Supplies", "Petty Cash", "Other"
    ];

    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenants;
    private readonly IUserRepository _users;
    private readonly IBranchRepository _branches;
    private readonly IWarehouseRepository _warehouses;
    private readonly IPriceListRepository _priceLists;
    private readonly IExpenseRepository _expenses;

    public CompleteOnboardingCommandHandler(
        ITenantContext tenantContext,
        ITenantRepository tenants,
        IUserRepository users,
        IBranchRepository branches,
        IWarehouseRepository warehouses,
        IPriceListRepository priceLists,
        IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _tenants = tenants;
        _users = users;
        _branches = branches;
        _warehouses = warehouses;
        _priceLists = priceLists;
        _expenses = expenses;
    }

    public async Task<Result<WorkspaceDto>> Handle(
        CompleteOnboardingCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(_tenantContext.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Error.NotFound("Organization not found.");
        }

        tenant.CompleteOnboarding(
            command.Name,
            command.BusinessType,
            command.CountryCode,
            command.Currency,
            command.ContactPhone,
            command.TaxId);

        await EnsureDefaultWarehouseAsync(tenant, cancellationToken);
        await EnsureDefaultPriceListAsync(tenant, cancellationToken);
        await EnsureDefaultExpenseCategoriesAsync(tenant, cancellationToken);

        var roles = Array.Empty<string>();
        var userId = _tenantContext.UserId;
        if (userId is not null)
        {
            var user = await _users.GetByIdWithRolesAsync(tenant.Id, userId.Value, cancellationToken);
            if (user is not null)
            {
                roles = user.Roles.Select(r => r.Name).ToArray();
            }
        }

        return Result.Success(new WorkspaceDto(
            tenant.Id,
            tenant.Name,
            tenant.Currency,
            tenant.CountryCode,
            tenant.BusinessType,
            tenant.OnboardingCompletedAt is not null,
            roles));
    }

    /// <summary>
    /// A shop cannot record stock without a warehouse; new users should never
    /// have to learn the concept. Idempotent: skipped when any warehouse exists.
    /// </summary>
    private async Task EnsureDefaultWarehouseAsync(
        Domain.Tenants.Tenant tenant, CancellationToken cancellationToken)
    {
        var warehouseCount = await _warehouses.CountAsync(tenant.Id, search: null, branchId: null, cancellationToken);
        if (warehouseCount > 0)
        {
            return;
        }

        var branch = (await _branches.ListAllAsync(tenant.Id, cancellationToken))
            .FirstOrDefault(b => b.IsActive);
        if (branch is null)
        {
            return;
        }

        await _warehouses.AddAsync(
            Warehouse.Create(tenant.Id, branch.Id, DefaultWarehouseName, DefaultWarehouseCode),
            cancellationToken);
    }

    /// <summary>
    /// Selling prices live on the tenant's default price list; without one the
    /// first product could never be priced. Idempotent via GetDefaultAsync.
    /// </summary>
    private async Task EnsureDefaultPriceListAsync(
        Domain.Tenants.Tenant tenant, CancellationToken cancellationToken)
    {
        var existing = await _priceLists.GetDefaultAsync(tenant.Id, cancellationToken);
        if (existing is not null)
        {
            return;
        }

        await _priceLists.AddAsync(
            PriceList.Create(tenant.Id, DefaultPriceListName, tenant.Currency, isDefault: true),
            cancellationToken);
    }

    /// <summary>
    /// Expenses are expected to be categorized; new users get a starter set of
    /// common outlays they can rename or delete before recording any. Idempotent:
    /// only creates categories whose name is not already taken.
    /// </summary>
    private async Task EnsureDefaultExpenseCategoriesAsync(
        Domain.Tenants.Tenant tenant, CancellationToken cancellationToken)
    {
        foreach (var name in DefaultExpenseCategoryNames)
        {
            var existing = await _expenses.GetCategoryByNameAsync(
                tenant.Id, name, cancellationToken);
            if (existing is not null)
            {
                continue;
            }

            await _expenses.AddCategoryAsync(
                Domain.Accounting.ExpenseCategory.Create(tenant.Id, name),
                cancellationToken);
        }
    }
}
