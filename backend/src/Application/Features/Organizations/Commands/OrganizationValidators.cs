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

public sealed class CompleteOnboardingCommandValidator : AbstractValidator<CompleteOnboardingCommand>
{
    private static readonly string[] AllowedBusinessTypes =
    {
        "retail", "wholesale", "manufacturing", "services",
        "school", "hospital", "hotel", "agriculture", "other",
    };

    public CompleteOnboardingCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.BusinessType)
            .Must(t => t is null || AllowedBusinessTypes.Contains(t.Trim().ToLowerInvariant()))
            .WithMessage("Unknown business type.");
        RuleFor(x => x.CountryCode)
            .NotEmpty()
            .Matches("^[A-Z]{2}$")
            .WithMessage("Country code must be a two-letter ISO code in uppercase.");
        RuleFor(x => x.Currency)
            .NotEmpty()
            .Matches("^[a-zA-Z]{3}$")
            .WithMessage("Currency must be a three-letter ISO 4217 code.");
        RuleFor(x => x.ContactPhone).MaximumLength(30);
        RuleFor(x => x.TaxId).MaximumLength(64);
    }
}
