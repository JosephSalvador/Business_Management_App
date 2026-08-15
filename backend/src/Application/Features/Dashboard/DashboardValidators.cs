using BusinessOS.Application.Features.Dashboard.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Dashboard;

public sealed class GetLowStockQueryValidator : AbstractValidator<GetLowStockQuery>
{
    public GetLowStockQueryValidator()
    {
        RuleFor(x => x.MaxQuantity).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}

public sealed class GetRecentActivityQueryValidator : AbstractValidator<GetRecentActivityQuery>
{
    public GetRecentActivityQueryValidator()
    {
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}
