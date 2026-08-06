using BusinessOS.Application.Features.Branches.Dtos;
using BusinessOS.Application.Features.Branches.Queries;
using BusinessOS.Application.Ports;
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
    string? Email) : IRequest<Result<BranchDto>>;

public sealed class CreateBranchCommandHandler : IRequestHandler<CreateBranchCommand, Result<BranchDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;

    public CreateBranchCommandHandler(ITenantContext tenantContext, IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _branches = branches;
    }

    public async Task<Result<BranchDto>> Handle(CreateBranchCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var normalizedCode = Branch.NormalizeCode(command.Code);
        if (await _branches.GetByCodeAsync(tenantId, normalizedCode, cancellationToken) is not null)
        {
            return Error.Conflict("A branch with this code already exists.");
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
