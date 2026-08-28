using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

/// <summary>
/// Lists the platform-wide tax categories (VAT_STANDARD, VAT_ZERO, ...) so
/// product forms can offer a real tax picker. Read-only; categories are
/// seeded platform data, not tenant data.
/// </summary>
public sealed record ListTaxCategoriesQuery()
    : IRequest<Result<IReadOnlyList<TaxCategoryDto>>>;

public sealed class ListTaxCategoriesQueryHandler
    : IRequestHandler<ListTaxCategoriesQuery, Result<IReadOnlyList<TaxCategoryDto>>>
{
    private readonly ITaxRuleRepository _taxRules;

    public ListTaxCategoriesQueryHandler(ITaxRuleRepository taxRules)
    {
        _taxRules = taxRules;
    }

    public async Task<Result<IReadOnlyList<TaxCategoryDto>>> Handle(
        ListTaxCategoriesQuery request, CancellationToken cancellationToken)
    {
        var categories = await _taxRules.ListCategoriesAsync(cancellationToken);
        return Result.Success<IReadOnlyList<TaxCategoryDto>>(
            categories.Select(c => new TaxCategoryDto(c.Id, c.Code, c.Name)).ToArray());
    }
}
