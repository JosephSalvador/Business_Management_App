using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Queries;

public sealed record ResolvePriceQuery(
    Guid ProductId,
    Guid? VariantId,
    Guid? BranchId,
    PriceType PriceType,
    decimal Quantity,
    DateTime? OnDate = null) : IRequest<Result<ResolvedPriceDto>>;

public sealed class ResolvePriceQueryHandler : IRequestHandler<ResolvePriceQuery, Result<ResolvedPriceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;
    private readonly IProductRepository _products;
    private readonly IBranchRepository _branches;

    public ResolvePriceQueryHandler(
        ITenantContext tenantContext,
        IPriceListRepository priceLists,
        IProductRepository products,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
        _products = products;
        _branches = branches;
    }

    public async Task<Result<ResolvedPriceDto>> Handle(ResolvePriceQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var priceList = await _priceLists.GetDefaultAsync(tenantId, cancellationToken);
        if (priceList is null)
        {
            return Error.NotFound("No default price list is configured for this tenant.");
        }

        var product = await _products.GetByIdAsync(tenantId, request.ProductId, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        if (product.HasVariants)
        {
            if (!request.VariantId.HasValue || product.Variants.All(v => v.Id != request.VariantId.Value))
            {
                return Error.Validation("A variant belonging to the product must be specified.");
            }
        }
        else if (request.VariantId.HasValue)
        {
            return Error.Validation("This product has no variants.");
        }

        if (request.BranchId.HasValue
            && await _branches.GetByIdAsync(tenantId, request.BranchId.Value, cancellationToken) is null)
        {
            return Error.Validation("The branch does not exist in this tenant.");
        }

        var onDate = request.OnDate ?? DateTime.UtcNow;
        var candidates = await _priceLists.ResolvePricesAsync(
            tenantId,
            priceList.Id,
            request.ProductId,
            request.VariantId,
            request.BranchId,
            request.PriceType,
            request.Quantity,
            onDate,
            cancellationToken);

        var resolved = PriceResolver.Resolve(
            candidates, request.ProductId, request.VariantId, request.BranchId, request.PriceType, request.Quantity, onDate);
        if (resolved is null)
        {
            return Error.NotFound("No price could be resolved for the given product.");
        }

        return Result.Success(PricingMappers.ToResolvedDto(resolved));
    }
}
