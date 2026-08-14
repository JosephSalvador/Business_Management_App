using BusinessOS.Application.Features.Inventory.Commands;
using FluentValidation;

namespace BusinessOS.Application.Features.Inventory;

public sealed class CreateWarehouseCommandValidator : AbstractValidator<CreateWarehouseCommand>
{
    public CreateWarehouseCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Code)
            .NotEmpty()
            .MaximumLength(50)
            .Matches("^[A-Za-z0-9-]+$").WithMessage("Code may only contain letters, digits and hyphens.");
        RuleFor(x => x.BranchId).NotEmpty();
        RuleFor(x => x.Description).MaximumLength(500);
    }
}

public sealed class UpdateWarehouseCommandValidator : AbstractValidator<UpdateWarehouseCommand>
{
    public UpdateWarehouseCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(500);
    }
}

public sealed class SetWarehouseStatusCommandValidator : AbstractValidator<SetWarehouseStatusCommand>
{
    public SetWarehouseStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class SetStockLocationsCommandValidator : AbstractValidator<SetStockLocationsCommand>
{
    public SetStockLocationsCommandValidator()
    {
        RuleFor(x => x.WarehouseId).NotEmpty();
        RuleFor(x => x.Locations).NotNull().NotEmpty();
        RuleForEach(x => x.Locations)
            .ChildRules(location =>
            {
                location.RuleFor(l => l.Code)
                    .NotEmpty()
                    .MaximumLength(50)
                    .Matches("^[A-Za-z0-9-]+$").WithMessage("Code may only contain letters, digits and hyphens.");
                location.RuleFor(l => l.Name).NotEmpty().MaximumLength(200);
            });
    }
}
