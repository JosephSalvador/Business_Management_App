using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Commands;

public sealed record UpdatePriceListCommand(
    Guid Id,
    string Name,
    string Currency,
    bool IsDefault,
    bool IsActive,
    DateTime? EffectiveFrom = null,
    DateTime? EffectiveTo = null)
    : IRequest<Result<PriceListDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdatePriceListCommandHandler : IRequestHandler<UpdatePriceListCommand, Result<PriceListDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;

    public UpdatePriceListCommandHandler(ITenantContext tenantContext, IPriceListRepository priceLists)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
    }

    public async Task<Result<PriceListDto>> Handle(UpdatePriceListCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var priceList = await _priceLists.GetByIdAsync(
            tenantId, command.Id, includePrices: false, cancellationToken);
        if (priceList is null)
        {
            return Error.NotFound("Price list not found.");
        }

        var name = command.Name.Trim();
        if (await _priceLists.GetByNameAsync(tenantId, name, cancellationToken) is { } owner && owner.Id != priceList.Id)
        {
            return Error.Conflict("A price list with this name already exists.");
        }

        if (command.IsDefault
            && await _priceLists.GetDefaultAsync(tenantId, cancellationToken) is { } currentDefault
            && currentDefault.Id != priceList.Id)
        {
            return Error.Conflict("A default price list already exists for this tenant.");
        }

        priceList.UpdateProfile(name, command.Currency, command.IsDefault, command.IsActive, command.EffectiveFrom, command.EffectiveTo);

        return Result.Success(PricingMappers.ToDto(priceList));
    }
}
