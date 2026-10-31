using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Invoicing.Validators;

public sealed class UpdateTenantDocumentConfigurationCommandValidator
    : AbstractValidator<UpdateTenantDocumentConfigurationCommand>
{
    private const string HexColorRegex = @"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$";

    public UpdateTenantDocumentConfigurationCommandValidator()
    {
        RuleFor(x => x.ActiveTemplateId).NotEmpty();
        RuleFor(x => x.DocumentType).IsInEnum();

        When(x => !string.IsNullOrWhiteSpace(x.ThemePrimaryHex), () =>
        {
            RuleFor(x => x.ThemePrimaryHex!)
                .Matches(HexColorRegex)
                .WithMessage("ThemePrimaryHex must be a valid hex color code (e.g. #0F172A or #000).");
        });

        When(x => !string.IsNullOrWhiteSpace(x.ThemeSecondaryHex), () =>
        {
            RuleFor(x => x.ThemeSecondaryHex!)
                .Matches(HexColorRegex)
                .WithMessage("ThemeSecondaryHex must be a valid hex color code (e.g. #64748B or #FFF).");
        });

        RuleFor(x => x.LogoUrl).MaximumLength(500);
        RuleFor(x => x.FooterNotes).MaximumLength(2000);
        RuleFor(x => x.CustomLiquidOverride).MaximumLength(50000);
    }
}

public sealed class PreviewDocumentTemplateQueryValidator
    : AbstractValidator<PreviewDocumentTemplateQuery>
{
    public PreviewDocumentTemplateQueryValidator()
    {
        RuleFor(x => x.LiquidLayout).NotEmpty().MaximumLength(50000);
        RuleFor(x => x.DocumentType).IsInEnum();
    }
}
