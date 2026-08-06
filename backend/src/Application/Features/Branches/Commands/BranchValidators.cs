using FluentValidation;

namespace BusinessOS.Application.Features.Branches.Commands;

public sealed class CreateBranchCommandValidator : AbstractValidator<CreateBranchCommand>
{
    public CreateBranchCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Code)
            .NotEmpty()
            .MaximumLength(50)
            .Matches("^[A-Za-z0-9-]+$").WithMessage("Code may only contain letters, digits and hyphens.");
        RuleFor(x => x.Currency)
            .NotEmpty()
            .Matches("^[A-Za-z]{3}$").WithMessage("Currency must be a 3-letter ISO 4217 code.");
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.Phone).MaximumLength(30);
        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(320);
    }
}

public sealed class UpdateBranchCommandValidator : AbstractValidator<UpdateBranchCommand>
{
    public UpdateBranchCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.Phone).MaximumLength(30);
        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(320);
    }
}

public sealed class SetBranchStatusCommandValidator : AbstractValidator<SetBranchStatusCommand>
{
    public SetBranchStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
