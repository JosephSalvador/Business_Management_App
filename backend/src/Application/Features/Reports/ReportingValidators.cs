using BusinessOS.Application.Features.Reports.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Reports.Validators;

public sealed class TaxSummaryQueryValidator : AbstractValidator<TaxSummaryQuery>
{
    public TaxSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesSummaryQueryValidator : AbstractValidator<SalesSummaryQuery>
{
    public SalesSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class TopProductsQueryValidator : AbstractValidator<TopProductsQuery>
{
    public TopProductsQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}

public sealed class ExportTaxSummaryCommandValidator : AbstractValidator<ExportTaxSummaryCommand>
{
    public ExportTaxSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportSalesSummaryCommandValidator : AbstractValidator<ExportSalesSummaryCommand>
{
    public ExportSalesSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportTopProductsCommandValidator : AbstractValidator<ExportTopProductsCommand>
{
    public ExportTopProductsCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}
