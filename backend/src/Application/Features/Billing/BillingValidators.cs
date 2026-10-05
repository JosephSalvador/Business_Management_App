using BusinessOS.Application.Features.Billing.Commands;
using FluentValidation;

namespace BusinessOS.Application.Features.Billing.Validators;

public sealed class RedeemVoucherCommandValidator : AbstractValidator<RedeemVoucherCommand>
{
    public RedeemVoucherCommandValidator()
    {
        RuleFor(x => x.Code)
            .NotEmpty()
            .MaximumLength(50);
    }
}

public sealed class MarkInvoicePaidCommandValidator : AbstractValidator<MarkInvoicePaidCommand>
{
    public MarkInvoicePaidCommandValidator()
    {
        RuleFor(x => x.InvoiceId).NotEmpty();
        RuleFor(x => x.Reference).NotEmpty().MaximumLength(100);
    }
}

public sealed class IssueVouchersCommandValidator : AbstractValidator<IssueVouchersCommand>
{
    public IssueVouchersCommandValidator()
    {
        RuleFor(x => x.Count).InclusiveBetween(1, 50);
        RuleFor(x => x.ValueDays).InclusiveBetween(1, 365);
        RuleFor(x => x.ExpiresAtUtc)
            .GreaterThan(DateTime.UtcNow)
            .When(x => x.ExpiresAtUtc is not null)
            .WithMessage("Expiry must be in the future.");
    }
}

public sealed class GetInvoiceQueryValidator : AbstractValidator<BusinessOS.Application.Features.Billing.Queries.GetInvoiceQuery>
{
    public GetInvoiceQueryValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}