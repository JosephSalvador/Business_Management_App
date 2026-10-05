using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Features.Crm.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Crm.Validators;

public sealed class SetCreditLimitCommandValidator : AbstractValidator<SetCreditLimitCommand>
{
    public SetCreditLimitCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Limit).GreaterThanOrEqualTo(0);
    }
}

public sealed class RecordCreditSaleCommandValidator : AbstractValidator<RecordCreditSaleCommand>
{
    public RecordCreditSaleCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
    }
}

public sealed class RecordCreditPaymentCommandValidator : AbstractValidator<RecordCreditPaymentCommand>
{
    public RecordCreditPaymentCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
    }
}

public sealed class GetCustomerCreditQueryValidator : AbstractValidator<GetCustomerCreditQuery>
{
    public GetCustomerCreditQueryValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
    }
}

public sealed class ListCreditTransactionsQueryValidator : AbstractValidator<ListCreditTransactionsQuery>
{
    public ListCreditTransactionsQueryValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Page).GreaterThan(0);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
    }
}
