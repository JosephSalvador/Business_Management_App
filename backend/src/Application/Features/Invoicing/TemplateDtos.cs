using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Application.Features.Invoicing;

public sealed record DocumentTemplateDto(
    Guid Id,
    string Name,
    string? Description,
    DocumentType DocumentType,
    string LiquidLayout,
    string? ThumbnailBase64,
    string EngineVersion,
    bool IsActive,
    bool IsDefault,
    int DisplayOrder,
    DateTime CreatedAt);

public sealed record DocumentTemplateSummaryDto(
    Guid Id,
    string Name,
    string? Description,
    DocumentType DocumentType,
    string? ThumbnailBase64,
    bool IsDefault,
    int DisplayOrder);

public sealed record TenantDocumentConfigurationDto(
    Guid Id,
    Guid TenantId,
    DocumentType DocumentType,
    Guid ActiveTemplateId,
    string? ActiveTemplateName,
    string? CustomLiquidOverride,
    string? ThemePrimaryHex,
    string? ThemeSecondaryHex,
    string? LogoUrl,
    bool ShowLogo,
    string? FooterNotes);

public sealed record UpdateTenantDocumentConfigurationRequest(
    Guid ActiveTemplateId,
    string? CustomLiquidOverride = null,
    string? ThemePrimaryHex = null,
    string? ThemeSecondaryHex = null,
    string? LogoUrl = null,
    bool ShowLogo = true,
    string? FooterNotes = null);

public sealed record PreviewTemplateRequest(
    string LiquidLayout,
    DocumentType DocumentType,
    string? ThemePrimaryHex = null,
    string? LogoUrl = null);
