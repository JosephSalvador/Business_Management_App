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
        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(320);
        RuleFor(x => x.ContactPhone).MaximumLength(30);
        RuleFor(x => x.Phone).MaximumLength(30);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.CountryCode)
            .NotEmpty()
            .Matches("^[A-Z]{2}$")
            .WithMessage("Country code must be a two-letter ISO code in uppercase.");
        RuleFor(x => x.TaxId).MaximumLength(64);
        RuleFor(x => x.BankName).MaximumLength(150);
        RuleFor(x => x.BankAccountName).MaximumLength(200);
        RuleFor(x => x.BankAccountNumber).MaximumLength(100);
        RuleFor(x => x.BankBranchOrSwift).MaximumLength(150);
        RuleFor(x => x.MobileMoneyDetails).MaximumLength(300);
        RuleFor(x => x.InvoiceTerms).MaximumLength(2000);
        RuleFor(x => x.AuthorizedSignatoryName).MaximumLength(150);
        RuleFor(x => x.AuthorizedSignatoryTitle).MaximumLength(150);
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
