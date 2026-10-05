using BusinessOS.Application.Features.Products.Commands;
using BusinessOS.Domain.Catalog;
using FluentValidation;

namespace BusinessOS.Application.Features.Products;

public sealed class CreateProductCommandValidator : AbstractValidator<CreateProductCommand>
{
    public CreateProductCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Sku).MaximumLength(64);
        RuleFor(x => x.Barcode).MaximumLength(64);
        RuleFor(x => x.UnitOfMeasureId).NotEmpty();
        RuleFor(x => x.ProductType).IsInEnum();
        RuleFor(x => x.Status).IsInEnum();
        RuleFor(x => x.CostPrice)
            .GreaterThanOrEqualTo(0).When(x => x.ProductType == ProductType.Product)
            .WithMessage("Bei ya kununua inahitajika kwa bidhaa. Inatusaidia kukokotoa thamani ya stock na faida.");
        RuleFor(x => x.CostPrice)
            .Null().When(x => x.ProductType == ProductType.Service)
            .WithMessage("Huduma hazina bei ya kununua.");
    }
}

public sealed class UpdateProductCommandValidator : AbstractValidator<UpdateProductCommand>
{
    public UpdateProductCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Sku).MaximumLength(64);
        RuleFor(x => x.Barcode).MaximumLength(64);
        RuleFor(x => x.UnitOfMeasureId).NotEmpty();
        RuleFor(x => x.CostPrice)
            .GreaterThanOrEqualTo(0).When(x => x.CostPrice.HasValue)
            .WithMessage("Bei ya kununua haiwezi kuwa chini ya sifa.");
    }
}

public sealed class SetProductStatusCommandValidator : AbstractValidator<SetProductStatusCommand>
{
    public SetProductStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Status).IsInEnum();
    }
}

public sealed class DeleteProductCommandValidator : AbstractValidator<DeleteProductCommand>
{
    public DeleteProductCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class SetProductVariantsCommandValidator : AbstractValidator<SetProductVariantsCommand>
{
    public SetProductVariantsCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Variants).NotEmpty().WithMessage("At least one variant is required.");
        RuleFor(x => x.Variants).Must(variants =>
        {
            var names = variants.Select(v => v.Name.Trim()).ToArray();
            return names.Distinct().Count() == names.Length;
        }).WithMessage("Variant names must be unique.");
        RuleForEach(x => x.Variants).ChildRules(variant =>
        {
            variant.RuleFor(v => v.Name).NotEmpty().MaximumLength(200);
            variant.RuleFor(v => v.Sku).MaximumLength(64);
            variant.RuleFor(v => v.Barcode).MaximumLength(64);
        });
    }
}
