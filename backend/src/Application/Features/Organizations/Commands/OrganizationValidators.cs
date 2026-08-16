using FluentValidation;

namespace BusinessOS.Application.Features.Organizations.Commands;

public sealed class UpdateOrganizationCommandValidator : AbstractValidator<UpdateOrganizationCommand>
{
    public UpdateOrganizationCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.ContactEmail)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.ContactEmail))
            .MaximumLength(320);
        RuleFor(x => x.ContactPhone).MaximumLength(30);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.CountryCode)
            .NotEmpty()
            .Matches("^[A-Z]{2}$")
            .WithMessage("Country code must be a two-letter ISO code in uppercase.");
        RuleFor(x => x.TaxId).MaximumLength(64);
    }
}
