using BusinessOS.Application.Features.Accounting.Commands;
using BusinessOS.Application.Features.Accounting.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Accounting.Validators;

public sealed class CreateAccountCommandValidator : AbstractValidator<CreateAccountCommand>
{
    public CreateAccountCommandValidator()
    {
        RuleFor(x => x.Code).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Type).IsInEnum();
    }
}

public sealed class UpdateAccountCommandValidator : AbstractValidator<UpdateAccountCommand>
{
    public UpdateAccountCommandValidator()
    {
        RuleFor(x => x.AccountId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Type).IsInEnum();
    }
}

public sealed class CreateJournalEntryCommandValidator : AbstractValidator<CreateJournalEntryCommand>
{
    public CreateJournalEntryCommandValidator()
    {
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
        RuleFor(x => x.EntryDate).NotEmpty();
        RuleFor(x => x.Lines).NotEmpty();
        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.AccountId).NotEmpty();
            line.RuleFor(l => l.DebitAmount).GreaterThanOrEqualTo(0);
            line.RuleFor(l => l.CreditAmount).GreaterThanOrEqualTo(0);
            line.RuleFor(l => l)
                .Must(l => l.DebitAmount > 0 ^ l.CreditAmount > 0)
                .WithMessage("Each line must have either a debit or credit amount, not both.");
        });
    }
}

public sealed class PostJournalEntryCommandValidator : AbstractValidator<PostJournalEntryCommand>
{
    public PostJournalEntryCommandValidator()
    {
        RuleFor(x => x.JournalEntryId).NotEmpty();
    }
}

public sealed class VoidJournalEntryCommandValidator : AbstractValidator<VoidJournalEntryCommand>
{
    public VoidJournalEntryCommandValidator()
    {
        RuleFor(x => x.JournalEntryId).NotEmpty();
    }
}

public sealed class ListAccountsQueryValidator : AbstractValidator<ListAccountsQuery>
{
}

public sealed class CreateTenantAccountMappingCommandValidator : AbstractValidator<CreateTenantAccountMappingCommand>
{
    public CreateTenantAccountMappingCommandValidator()
    {
        RuleFor(x => x.MappingKey).NotEmpty().MaximumLength(100);
        RuleFor(x => x.AccountId).NotEmpty();
    }
}

public sealed class CreateExpenseCommandValidator : AbstractValidator<CreateExpenseCommand>
{
    public CreateExpenseCommandValidator()
    {
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.ExpenseDate).NotEmpty();
        RuleFor(x => x.CategoryId).NotEmpty()
            .WithMessage("Gharama lazima iwe na kundi. Tafadhali chagua kundi la gharama.");
        RuleFor(x => x.PaymentMethod).MaximumLength(100).When(x => x.PaymentMethod != null);
        RuleFor(x => x.Reference).MaximumLength(200).When(x => x.Reference != null);
    }
}

public sealed class UpdateExpenseCommandValidator : AbstractValidator<UpdateExpenseCommand>
{
    public UpdateExpenseCommandValidator()
    {
        RuleFor(x => x.ExpenseId).NotEmpty();
        RuleFor(x => x.Description).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.ExpenseDate).NotEmpty();
        RuleFor(x => x.CategoryId).NotEmpty()
            .WithMessage("Gharama lazima iwe na kundi. Tafadhali chagua kundi la gharama.");
        RuleFor(x => x.PaymentMethod).MaximumLength(100).When(x => x.PaymentMethod != null);
        RuleFor(x => x.Reference).MaximumLength(200).When(x => x.Reference != null);
    }
}

public sealed class ListExpensesQueryValidator : AbstractValidator<ListExpensesQuery>
{
    public ListExpensesQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThan(0);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
        RuleFor(x => x.FromDate).LessThanOrEqualTo(x => x.ToDate).When(x => x.FromDate.HasValue && x.ToDate.HasValue);
    }
}

public sealed class CreateExpenseCategoryCommandValidator : AbstractValidator<CreateExpenseCategoryCommand>
{
    public CreateExpenseCategoryCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(50);
    }
}

public sealed class GetExpenseSummaryQueryValidator : AbstractValidator<GetExpenseSummaryQuery>
{
    public GetExpenseSummaryQueryValidator()
    {
        RuleFor(x => x.FromDate)
            .LessThanOrEqualTo(x => x.ToDate)
            .When(x => x.FromDate.HasValue && x.ToDate.HasValue);
    }
}
