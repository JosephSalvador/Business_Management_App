using BusinessOS.Application.Features.Pricing.Commands;
using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Features.Pricing.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Pricing;

public sealed class CreatePriceListCommandValidator : AbstractValidator<CreatePriceListCommand>
{
    public CreatePriceListCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Currency)
            .NotEmpty()
            .Matches("^[A-Za-z]{3}$").WithMessage("Currency must be a three-letter ISO 4217 code.");
        RuleFor(x => x).Must(HaveValidWindow).WithMessage("EffectiveFrom must be before or equal to EffectiveTo.");
    }

    private static bool HaveValidWindow(CreatePriceListCommand command)
        => command.EffectiveFrom is null
            || command.EffectiveTo is null
            || command.EffectiveFrom <= command.EffectiveTo;
}

public sealed class UpdatePriceListCommandValidator : AbstractValidator<UpdatePriceListCommand>
{
    public UpdatePriceListCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Currency)
            .NotEmpty()
            .Matches("^[A-Za-z]{3}$").WithMessage("Currency must be a three-letter ISO 4217 code.");
        RuleFor(x => x).Must(HaveValidWindow).WithMessage("EffectiveFrom must be before or equal to EffectiveTo.");
    }

    private static bool HaveValidWindow(UpdatePriceListCommand command)
        => command.EffectiveFrom is null
            || command.EffectiveTo is null
            || command.EffectiveFrom <= command.EffectiveTo;
}

public sealed class SetProductPricesCommandValidator : AbstractValidator<SetProductPricesCommand>
{
    public SetProductPricesCommandValidator()
    {
        RuleFor(x => x.PriceListId).NotEmpty();
        RuleFor(x => x.Prices).NotNull().NotEmpty();
        RuleForEach(x => x.Prices).ChildRules(price =>
        {
            price.RuleFor(p => p.ProductId).NotEmpty();
            price.RuleFor(p => p.Currency)
                .NotEmpty()
                .Matches("^[A-Za-z]{3}$").WithMessage("Currency must be a three-letter ISO 4217 code.");
            price.RuleFor(p => p.Price).GreaterThan(0);
            price.RuleFor(p => p.MinQuantity).GreaterThanOrEqualTo(1);
            price.RuleFor(p => p).Must(HaveValidWindow).WithMessage("EffectiveFrom must be before or equal to EffectiveTo.");
        });
    }

    private static bool HaveValidWindow(ProductPriceInputDto price)
        => price.EffectiveFrom is null
            || price.EffectiveTo is null
            || price.EffectiveFrom <= price.EffectiveTo;
}

public sealed class GetPriceListPricesQueryValidator : AbstractValidator<GetPriceListPricesQuery>
{
    public GetPriceListPricesQueryValidator() => RuleFor(x => x.PriceListId).NotEmpty();
}

public sealed class ResolvePriceQueryValidator : AbstractValidator<ResolvePriceQuery>
{
    public ResolvePriceQueryValidator()
    {
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.Quantity).GreaterThanOrEqualTo(1);
    }
}

public sealed class ResolvePricesQueryValidator : AbstractValidator<ResolvePricesQuery>
{
    public ResolvePricesQueryValidator()
    {
        RuleFor(x => x.Lines).NotNull().NotEmpty();
        RuleFor(x => x.Lines.Count).LessThanOrEqualTo(100);
        RuleFor(x => x.PriceType).IsInEnum();
        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.ProductId).NotEmpty();
            line.RuleFor(l => l.Quantity).GreaterThanOrEqualTo(1);
        });
    }
}
