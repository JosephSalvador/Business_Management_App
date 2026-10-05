using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Features.Crm.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Crm.Validators;

public sealed class CreateCustomerCommandValidator : AbstractValidator<CreateCustomerCommand>
{
    public CreateCustomerCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Email).EmailAddress().When(x => x.Email != null);
        RuleFor(x => x.Phone).MaximumLength(30).When(x => x.Phone != null);
        RuleFor(x => x.Tin).MaximumLength(64).When(x => x.Tin != null);
    }
}

public sealed class UpdateCustomerCommandValidator : AbstractValidator<UpdateCustomerCommand>
{
    public UpdateCustomerCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Name).MaximumLength(200).When(x => x.Name != null);
        RuleFor(x => x.Email).EmailAddress().When(x => x.Email != null);
        RuleFor(x => x.Phone).MaximumLength(30).When(x => x.Phone != null);
        RuleFor(x => x.Tin).MaximumLength(64).When(x => x.Tin != null);
    }
}

public sealed class ListCustomersQueryValidator : AbstractValidator<ListCustomersQuery>
{
    public ListCustomersQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThan(0);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
    }
}
