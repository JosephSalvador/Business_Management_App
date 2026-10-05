using BusinessOS.Application.Features.Billing;
using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Features.Branches.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Branches.Commands;

public sealed record CreateBranchCommand(
    string Name,
    string Code,
    string Currency,
    string? Address,
    string? Phone,
    string? Email) : IRequest<Result<BranchDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateBranchCommandHandler : IRequestHandler<CreateBranchCommand, Result<BranchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;
    private readonly SubscriptionEntitlementGuard _entitlementGuard;

    public CreateBranchCommandHandler(
        ITenantContext tenantContext,
        IBranchRepository branches,
        SubscriptionEntitlementGuard entitlementGuard)
    {
        _tenantContext = tenantContext;
        _branches = branches;
        _entitlementGuard = entitlementGuard;
    }

    public async Task<Result<BranchDto>> Handle(CreateBranchCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var normalizedCode = Branch.NormalizeCode(command.Code);
        if (await _branches.GetByCodeAsync(tenantId, normalizedCode, cancellationToken) is not null)
        {
            return Error.Conflict("A branch with this code already exists.");
        }

        var existingBranches = await _branches.CountAsync(tenantId, cancellationToken);
        if (existingBranches >= 1)
        {
            var entitlement = await _entitlementGuard.GetEntitlementAsync(cancellationToken);
            if (SubscriptionEntitlementGuard.EnsureFeature(entitlement, FeatureKeys.MultiBranch)
                is { } moduleError)
            {
                return moduleError;
            }

            if (SubscriptionEntitlementGuard.EnsureWithinLimit(
                    entitlement.MaxBranches, existingBranches + 1, "branches") is { } limitError)
            {
                return limitError;
            }
        }

        var branch = Branch.Create(
            tenantId,
            command.Name,
            normalizedCode,
            command.Currency.Trim().ToUpperInvariant(),
            command.Address,
            command.Phone,
            command.Email);

        await _branches.AddAsync(branch, cancellationToken);
        return Result.Success(ListBranchesQueryHandler.ToDto(branch));
    }
}
