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

public sealed class RecordOpeningStockCommandValidator : AbstractValidator<RecordOpeningStockCommand>
{
    public RecordOpeningStockCommandValidator()
    {
        RuleFor(x => x.WarehouseId).NotEmpty();
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.UnitOfMeasureId).NotEmpty();
        RuleFor(x => x.Quantity).GreaterThan(0);
        RuleFor(x => x.EffectiveAt).NotEqual(default(DateTime));
        RuleFor(x => x.ReferenceType).MaximumLength(100);
        RuleFor(x => x.Reason).MaximumLength(500);
        RuleFor(x => x.CorrelationId).MaximumLength(64);
    }
}

public sealed class AdjustStockCommandValidator : AbstractValidator<AdjustStockCommand>
{
    public AdjustStockCommandValidator()
    {
        RuleFor(x => x.WarehouseId).NotEmpty();
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.QuantityDelta).NotEqual(0);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(500);
        RuleFor(x => x.EffectiveAt).LessThanOrEqualTo(DateTime.UtcNow.AddMinutes(5));
    }
}

public sealed class CreateTransferCommandValidator : AbstractValidator<CreateTransferCommand>
{
    public CreateTransferCommandValidator()
    {
        RuleFor(x => x.SourceWarehouseId).NotEmpty();
        RuleFor(x => x.DestinationWarehouseId).NotEmpty();
        RuleFor(x => x.Lines).NotEmpty();
        RuleFor(x => x.Reason).MaximumLength(500);
        RuleFor(x => x.ReferenceType).MaximumLength(100);
        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.ProductId).NotEmpty();
            line.RuleFor(l => l.Quantity).GreaterThan(0);
        });
    }
}

public sealed class CompleteTransferCommandValidator : AbstractValidator<CompleteTransferCommand>
{
    public CompleteTransferCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class CancelTransferCommandValidator : AbstractValidator<CancelTransferCommand>
{
    public CancelTransferCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class CreateStockCountCommandValidator : AbstractValidator<CreateStockCountCommand>
{
    public CreateStockCountCommandValidator()
    {
        RuleFor(x => x.WarehouseId).NotEmpty();
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.CountedQuantity).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed class CompleteStockCountCommandValidator : AbstractValidator<CompleteStockCountCommand>
{
    public CompleteStockCountCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class CancelStockCountCommandValidator : AbstractValidator<CancelStockCountCommand>
{
    public CancelStockCountCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class CreateStockBatchCommandValidator : AbstractValidator<CreateStockBatchCommand>
{
    public CreateStockBatchCommandValidator()
    {
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.BatchNumber).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed class SetStockBatchStatusCommandValidator : AbstractValidator<SetStockBatchStatusCommand>
{
    public SetStockBatchStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
