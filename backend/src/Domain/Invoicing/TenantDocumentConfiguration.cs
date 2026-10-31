using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// Tenant-specific document configuration linking a tenant to their active template selection
/// or sanitized custom Liquid layout override, with branding theme colors and logo options.
/// </summary>
public sealed class TenantDocumentConfiguration : AggregateRoot
{
    private TenantDocumentConfiguration(
        Guid id,
        Guid tenantId,
        DocumentType documentType,
        Guid activeTemplateId,
        string? customLiquidOverride,
        string? themePrimaryHex,
        string? themeSecondaryHex,
        string? logoUrl,
        bool showLogo,
        string? footerNotes)
        : base(id)
    {
        TenantId = tenantId;
        DocumentType = documentType;
        ActiveTemplateId = activeTemplateId;
        CustomLiquidOverride = customLiquidOverride;
        ThemePrimaryHex = themePrimaryHex;
        ThemeSecondaryHex = themeSecondaryHex;
        LogoUrl = logoUrl;
        ShowLogo = showLogo;
        FooterNotes = footerNotes;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public DocumentType DocumentType { get; private set; }
    public Guid ActiveTemplateId { get; private set; }
    public string? CustomLiquidOverride { get; private set; }
    public string? ThemePrimaryHex { get; private set; }
    public string? ThemeSecondaryHex { get; private set; }
    public string? LogoUrl { get; private set; }
    public bool ShowLogo { get; private set; }
    public string? FooterNotes { get; private set; }

    public static TenantDocumentConfiguration Create(
        Guid tenantId,
        DocumentType documentType,
        Guid activeTemplateId,
        string? customLiquidOverride = null,
        string? themePrimaryHex = null,
        string? themeSecondaryHex = null,
        string? logoUrl = null,
        bool showLogo = true,
        string? footerNotes = null,
        Guid? id = null)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant ID is required.", nameof(tenantId));
        }

        if (activeTemplateId == Guid.Empty)
        {
            throw new ArgumentException("An active template ID is required.", nameof(activeTemplateId));
        }

        return new TenantDocumentConfiguration(
            id: id.HasValue && id.Value != Guid.Empty ? id.Value : Guid.NewGuid(),
            tenantId: tenantId,
            documentType: documentType,
            activeTemplateId: activeTemplateId,
            customLiquidOverride: string.IsNullOrWhiteSpace(customLiquidOverride) ? null : customLiquidOverride.Trim(),
            themePrimaryHex: NormalizeHex(themePrimaryHex),
            themeSecondaryHex: NormalizeHex(themeSecondaryHex),
            logoUrl: string.IsNullOrWhiteSpace(logoUrl) ? null : logoUrl.Trim(),
            showLogo: showLogo,
            footerNotes: string.IsNullOrWhiteSpace(footerNotes) ? null : footerNotes.Trim());
    }

    public void UpdateConfiguration(
        Guid activeTemplateId,
        string? customLiquidOverride,
        string? themePrimaryHex,
        string? themeSecondaryHex,
        string? logoUrl,
        bool showLogo,
        string? footerNotes)
    {
        if (activeTemplateId == Guid.Empty)
        {
            throw new ArgumentException("An active template ID is required.", nameof(activeTemplateId));
        }

        ActiveTemplateId = activeTemplateId;
        CustomLiquidOverride = string.IsNullOrWhiteSpace(customLiquidOverride) ? null : customLiquidOverride.Trim();
        ThemePrimaryHex = NormalizeHex(themePrimaryHex);
        ThemeSecondaryHex = NormalizeHex(themeSecondaryHex);
        LogoUrl = string.IsNullOrWhiteSpace(logoUrl) ? null : logoUrl.Trim();
        ShowLogo = showLogo;
        FooterNotes = string.IsNullOrWhiteSpace(footerNotes) ? null : footerNotes.Trim();
        UpdatedAt = DateTime.UtcNow;
    }

    private static string? NormalizeHex(string? hex)
    {
        if (string.IsNullOrWhiteSpace(hex)) return null;
        var clean = hex.Trim();
        return clean.StartsWith('#') ? clean : $"#{clean}";
    }
}
