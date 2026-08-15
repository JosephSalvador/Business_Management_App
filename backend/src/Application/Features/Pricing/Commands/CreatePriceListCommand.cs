using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Commands;

public sealed record CreatePriceListCommand(
    string Name,
    string Currency,
    bool IsDefault,
    DateTime? EffectiveFrom = null,
    DateTime? EffectiveTo = null)
    : IRequest<Result<PriceListDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreatePriceListCommandHandler : IRequestHandler<CreatePriceListCommand, Result<PriceListDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;

    public CreatePriceListCommandHandler(ITenantContext tenantContext, IPriceListRepository priceLists)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
    }

    public async Task<Result<PriceListDto>> Handle(CreatePriceListCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var name = command.Name.Trim();
        if (await _priceLists.GetByNameAsync(tenantId, name, cancellationToken) is not null)
        {
            return Error.Conflict("A price list with this name already exists.");
        }

        if (command.IsDefault && await _priceLists.GetDefaultAsync(tenantId, cancellationToken) is not null)
        {
            return Error.Conflict("A default price list already exists for this tenant.");
        }

        var priceList = PriceList.Create(
            tenantId, name, command.Currency, command.IsDefault, command.EffectiveFrom, command.EffectiveTo);

        await _priceLists.AddAsync(priceList, cancellationToken);
        return Result.Success(PricingMappers.ToDto(priceList));
    }
}
