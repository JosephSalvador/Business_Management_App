using BusinessOS.Application.Features.Finance.Commands;
using BusinessOS.Application.Features.Finance.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Finance.Validators;

public sealed class CreateMoneyAccountCommandValidator : AbstractValidator<CreateMoneyAccountCommand>
{
    public CreateMoneyAccountCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Type).IsInEnum();
    }
}

public sealed class TransferMoneyCommandValidator : AbstractValidator<TransferMoneyCommand>
{
    public TransferMoneyCommandValidator()
    {
        RuleFor(x => x.FromAccountId).NotEmpty();
        RuleFor(x => x.ToAccountId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
    }
}

public sealed class RecordIncomeCommandValidator : AbstractValidator<RecordIncomeCommand>
{
    public RecordIncomeCommandValidator()
    {
        RuleFor(x => x.AccountId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
    }
}

public sealed class RecordAccountExpenseCommandValidator : AbstractValidator<RecordAccountExpenseCommand>
{
    public RecordAccountExpenseCommandValidator()
    {
        RuleFor(x => x.AccountId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
    }
}

public sealed class OpenCashSessionCommandValidator : AbstractValidator<OpenCashSessionCommand>
{
    public OpenCashSessionCommandValidator()
    {
        RuleFor(x => x.AccountId).NotEmpty();
        RuleFor(x => x.OpeningCash).GreaterThanOrEqualTo(0);
    }
}

public sealed class CloseCashSessionCommandValidator : AbstractValidator<CloseCashSessionCommand>
{
    public CloseCashSessionCommandValidator()
    {
        RuleFor(x => x.SessionId).NotEmpty();
        RuleFor(x => x.ClosingCash).GreaterThanOrEqualTo(0);
    }
}