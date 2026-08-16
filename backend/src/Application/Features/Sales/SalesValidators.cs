using BusinessOS.Application.Features.Sales.Commands;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Features.Sales.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Sales;

public sealed class CreateSaleCommandValidator : AbstractValidator<CreateSaleCommand>
{
    private static readonly TimeSpan FutureSkew = TimeSpan.FromMinutes(5);

    public CreateSaleCommandValidator()
    {
        RuleFor(x => x.BranchId).NotEmpty();
        RuleFor(x => x.ClientSaleId).NotEmpty();
        RuleFor(x => x.Source).IsInEnum();
        RuleFor(x => x.EffectiveAt)
            .NotEmpty()
            .LessThanOrEqualTo(DateTime.UtcNow.Add(FutureSkew))
            .WithMessage("EffectiveAt cannot be in the future beyond a small skew window.");
        RuleFor(x => x.Lines).NotNull().NotEmpty().WithMessage("A sale requires at least one line.");
        RuleFor(x => x.Payments).NotNull().NotEmpty().WithMessage("A sale requires at least one payment.");

        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.ProductId).NotEmpty();
            line.RuleFor(l => l.Quantity).GreaterThanOrEqualTo(1);
            line.RuleFor(l => l.DiscountAmount).GreaterThanOrEqualTo(0);
        });

        RuleForEach(x => x.Payments).ChildRules(payment =>
        {
            payment.RuleFor(p => p.Method).IsInEnum();
            payment.RuleFor(p => p.Amount).GreaterThan(0);
        });

        RuleFor(x => x.CustomerName).MaximumLength(200);
        RuleFor(x => x.CustomerPhone).MaximumLength(30);
        RuleFor(x => x.CustomerTin).MaximumLength(50);
    }
}

public sealed class GetSaleQueryValidator : AbstractValidator<GetSaleQuery>
{
    public GetSaleQueryValidator() => RuleFor(x => x.Id).NotEmpty();
}

public sealed class ListSalesQueryValidator : AbstractValidator<ListSalesQuery>
{
    public ListSalesQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
        RuleFor(x => x.Search).MaximumLength(200);
        RuleFor(x => x).Must(HaveValidDateRange)
            .WithMessage("FromDate must be before or equal to ToDate.");
    }

    private static bool HaveValidDateRange(ListSalesQuery query)
        => query.FromDate is null || query.ToDate is null || query.FromDate <= query.ToDate;
}
