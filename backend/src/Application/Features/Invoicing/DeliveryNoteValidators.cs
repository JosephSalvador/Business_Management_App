using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Invoicing.Validators;

public sealed class CreateDeliveryNoteCommandValidator : AbstractValidator<CreateDeliveryNoteCommand>
{
    public CreateDeliveryNoteCommandValidator()
    {
        RuleFor(x => x.CustomerName).MaximumLength(200);
        RuleFor(x => x.CustomerAttention).MaximumLength(200);
        RuleFor(x => x.CustomerPhone).MaximumLength(50);
        RuleFor(x => x.DeliveryAddress).MaximumLength(500);
        RuleFor(x => x.VehicleNumber).MaximumLength(50);
        RuleFor(x => x.DriverName).MaximumLength(100);
        RuleFor(x => x.DriverPhone).MaximumLength(50);
        RuleFor(x => x.Notes).MaximumLength(2000);

        RuleFor(x => x)
            .Must(cmd => (cmd.InvoiceId.HasValue && cmd.InvoiceId.Value != Guid.Empty) || (cmd.Items != null && cmd.Items.Count > 0))
            .WithMessage("A delivery note must reference an invoice or contain at least one line item.");

        When(x => x.Items != null && x.Items.Count > 0, () =>
        {
            RuleForEach(x => x.Items!).ChildRules(item =>
            {
                item.RuleFor(i => i.Description).NotEmpty().MaximumLength(500);
                item.RuleFor(i => i.UnitOfMeasure).MaximumLength(50);
                item.RuleFor(i => i.QuantityOrdered).GreaterThanOrEqualTo(0);
                item.RuleFor(i => i.QuantityDelivered).GreaterThanOrEqualTo(0);
            });
        });
    }
}

public sealed class MarkDeliveryNoteDispatchedCommandValidator : AbstractValidator<MarkDeliveryNoteDispatchedCommand>
{
    public MarkDeliveryNoteDispatchedCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.VehicleNumber).MaximumLength(50);
        RuleFor(x => x.DriverName).MaximumLength(100);
        RuleFor(x => x.DriverPhone).MaximumLength(50);
    }
}

public sealed class MarkDeliveryNoteDeliveredCommandValidator : AbstractValidator<MarkDeliveryNoteDeliveredCommand>
{
    public MarkDeliveryNoteDeliveredCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ReceivedByName).MaximumLength(100);
    }
}

public sealed class CancelDeliveryNoteCommandValidator : AbstractValidator<CancelDeliveryNoteCommand>
{
    public CancelDeliveryNoteCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Reason).MaximumLength(500);
    }
}

public sealed class ListDeliveryNotesQueryValidator : AbstractValidator<ListDeliveryNotesQuery>
{
    public ListDeliveryNotesQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
    }
}
