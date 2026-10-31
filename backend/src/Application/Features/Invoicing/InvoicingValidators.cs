using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Invoicing.Validators;

public sealed class CreateCustomerInvoiceCommandValidator : AbstractValidator<CreateCustomerInvoiceCommand>
{
    public CreateCustomerInvoiceCommandValidator()
    {
        RuleFor(x => x.Currency).NotEmpty().MaximumLength(3);
        RuleFor(x => x.DocumentTitle).MaximumLength(50);
        RuleFor(x => x.ReferenceNumber).MaximumLength(100);
        RuleFor(x => x.PaymentTerms).MaximumLength(100);
        RuleFor(x => x.CustomerName).MaximumLength(200);
        RuleFor(x => x.CustomerAttention).MaximumLength(200);
        RuleFor(x => x.CustomerPhone).MaximumLength(50);
        RuleFor(x => x.CustomerEmail).MaximumLength(320);
        RuleFor(x => x.CustomerAddress).MaximumLength(500);
        RuleFor(x => x.CustomerTin).MaximumLength(64);
        RuleFor(x => x.DiscountAmount).GreaterThanOrEqualTo(0);
        RuleFor(x => x.InitialAmountPaid).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PaymentInstructions).MaximumLength(2000);
        RuleFor(x => x.AuthorizedSignatoryName).MaximumLength(150);
        RuleFor(x => x.AuthorizedSignatoryTitle).MaximumLength(150);
        RuleFor(x => x.Notes).MaximumLength(2000);
        RuleFor(x => x.Lines).NotEmpty();
        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.Description).NotEmpty().MaximumLength(500);
            line.RuleFor(l => l.UnitOfMeasure).MaximumLength(50);
            line.RuleFor(l => l.Quantity).GreaterThan(0);
            line.RuleFor(l => l.UnitPrice).GreaterThanOrEqualTo(0);
            line.RuleFor(l => l.DiscountAmount).GreaterThanOrEqualTo(0);
            line.RuleFor(l => l.TaxRatePercent).InclusiveBetween(0, 100);
        });
    }
}

public sealed class RecordCustomerInvoicePaymentCommandValidator
    : AbstractValidator<RecordCustomerInvoicePaymentCommand>
{
    public RecordCustomerInvoicePaymentCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Method).MaximumLength(50);
        RuleFor(x => x.Reference).MaximumLength(100);
    }
}

public sealed class VoidCustomerInvoiceCommandValidator : AbstractValidator<VoidCustomerInvoiceCommand>
{
    public VoidCustomerInvoiceCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class ListCustomerInvoicesQueryValidator : AbstractValidator<ListCustomerInvoicesQuery>
{
    public ListCustomerInvoicesQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThan(0);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
        RuleFor(x => x.Search).MaximumLength(200);
    }
}

public sealed class GetCustomerInvoiceQueryValidator : AbstractValidator<GetCustomerInvoiceQuery>
{
    public GetCustomerInvoiceQueryValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
