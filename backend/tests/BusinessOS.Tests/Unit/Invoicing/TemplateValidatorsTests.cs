using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Validators;
using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class TemplateValidatorsTests
{
    private readonly UpdateTenantDocumentConfigurationCommandValidator _validator = new();

    [Fact]
    public void Validate_ValidCommand_Passes()
    {
        var command = new UpdateTenantDocumentConfigurationCommand(
            DocumentType: DocumentType.Invoice,
            ActiveTemplateId: Guid.NewGuid(),
            ThemePrimaryHex: "#0F172A",
            ThemeSecondaryHex: "#64748B",
            ShowLogo: true);

        var result = _validator.Validate(command);

        Assert.True(result.IsValid);
    }

    [Theory]
    [InlineData("not-a-color")]
    [InlineData("#12345")]
    [InlineData("#1234567")]
    [InlineData("0F172A")]
    public void Validate_InvalidHexColor_Fails(string invalidHex)
    {
        var command = new UpdateTenantDocumentConfigurationCommand(
            DocumentType: DocumentType.Invoice,
            ActiveTemplateId: Guid.NewGuid(),
            ThemePrimaryHex: invalidHex);

        var result = _validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.PropertyName == "ThemePrimaryHex");
    }

    [Fact]
    public void Validate_EmptyTemplateId_Fails()
    {
        var command = new UpdateTenantDocumentConfigurationCommand(
            DocumentType: DocumentType.Invoice,
            ActiveTemplateId: Guid.Empty);

        var result = _validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.PropertyName == "ActiveTemplateId");
    }
}
