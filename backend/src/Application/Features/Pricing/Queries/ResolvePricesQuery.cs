using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Queries;

public sealed record ResolvePricesQuery(
    IReadOnlyList<ResolvePriceLineDto> Lines,
    Guid? BranchId,
    PriceType PriceType,
    DateTime? OnDate = null) : IRequest<Result<IReadOnlyList<ResolvedLineDto>>>;

/// Resolves selling prices for many cart lines in ONE round trip by reusing the
/// single-line resolution for each item. This is what the POS calls at checkout
/// so a whole cart prices in a single request instead of N.
public sealed class ResolvePricesQueryHandler
    : IRequestHandler<ResolvePricesQuery, Result<IReadOnlyList<ResolvedLineDto>>>
{
    private readonly IRequestHandler<ResolvePriceQuery, Result<ResolvedPriceDto>> _resolveOne;

    public ResolvePricesQueryHandler(
        IRequestHandler<ResolvePriceQuery, Result<ResolvedPriceDto>> resolveOne)
    {
        _resolveOne = resolveOne;
    }

    public async Task<Result<IReadOnlyList<ResolvedLineDto>>> Handle(
        ResolvePricesQuery request,
        CancellationToken cancellationToken)
    {
        if (request.Lines.Count == 0)
        {
            return Error.Validation("At least one line is required.");
        }
        if (request.Lines.Count > 100)
        {
            return Error.Validation("Cannot resolve more than 100 lines at once.");
        }

        var results = new List<ResolvedLineDto>(request.Lines.Count);
        foreach (var line in request.Lines)
        {
            var single = await _resolveOne.Handle(
                new ResolvePriceQuery(
                    line.ProductId,
                    line.VariantId,
                    request.BranchId,
                    request.PriceType,
                    line.Quantity,
                    request.OnDate),
                cancellationToken);
            results.Add(single.IsSuccess
                ? new ResolvedLineDto(line.ProductId, line.VariantId, single.Value.Price, single.Value.Currency, null)
                : new ResolvedLineDto(line.ProductId, line.VariantId, null, null, single.Error.Message));
        }

        return Result.Success((IReadOnlyList<ResolvedLineDto>)results);
    }
}