using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Commands;

public static class TemplateMappers
{
    public static DocumentTemplateDto ToDto(DocumentTemplate template) => new(
        template.Id,
        template.Name,
        template.Description,
        template.DocumentType,
        template.LiquidLayout,
        template.ThumbnailBase64,
        template.EngineVersion,
        template.IsActive,
        template.IsDefault,
        template.DisplayOrder,
        template.CreatedAt);

    public static DocumentTemplateSummaryDto ToSummary(DocumentTemplate template) => new(
        template.Id,
        template.Name,
        template.Description,
        template.DocumentType,
        template.ThumbnailBase64,
        template.IsDefault,
        template.DisplayOrder);

    public static TenantDocumentConfigurationDto ToDto(
        TenantDocumentConfiguration config, string? activeTemplateName = null) => new(
        config.Id,
        config.TenantId,
        config.DocumentType,
        config.ActiveTemplateId,
        activeTemplateName,
        config.CustomLiquidOverride,
        config.ThemePrimaryHex,
        config.ThemeSecondaryHex,
        config.LogoUrl,
        config.ShowLogo,
        config.FooterNotes);
}

public sealed record UpdateTenantDocumentConfigurationCommand(
    DocumentType DocumentType,
    Guid ActiveTemplateId,
    string? CustomLiquidOverride = null,
    string? ThemePrimaryHex = null,
    string? ThemeSecondaryHex = null,
    string? LogoUrl = null,
    bool ShowLogo = true,
    string? FooterNotes = null)
    : IRequest<Result<TenantDocumentConfigurationDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateTenantDocumentConfigurationCommandHandler
    : IRequestHandler<UpdateTenantDocumentConfigurationCommand, Result<TenantDocumentConfigurationDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantDocumentConfigurationRepository _configs;
    private readonly IDocumentTemplateRepository _templates;
    private readonly IHtmlSanitizerService _sanitizer;

    public UpdateTenantDocumentConfigurationCommandHandler(
        ITenantContext tenantContext,
        ITenantDocumentConfigurationRepository configs,
        IDocumentTemplateRepository templates,
        IHtmlSanitizerService sanitizer)
    {
        _tenantContext = tenantContext;
        _configs = configs;
        _templates = templates;
        _sanitizer = sanitizer;
    }

    public async Task<Result<TenantDocumentConfigurationDto>> Handle(
        UpdateTenantDocumentConfigurationCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        if (tenantId == Guid.Empty)
        {
            return Result<TenantDocumentConfigurationDto>.Failure(
                Error.Unauthorized("AUTH_TENANT_MISSING", "Tenant context is required."));
        }

        var template = await _templates.GetByIdAsync(request.ActiveTemplateId, cancellationToken);
        if (template is null)
        {
            return Result<TenantDocumentConfigurationDto>.Failure(
                Error.NotFound("TEMPLATE_NOT_FOUND", $"Marketplace template '{request.ActiveTemplateId}' was not found."));
        }

        if (template.DocumentType != request.DocumentType)
        {
            return Result<TenantDocumentConfigurationDto>.Failure(
                Error.Validation("TEMPLATE_TYPE_MISMATCH", $"Selected template is for {template.DocumentType}, not {request.DocumentType}."));
        }

        // Force custom HTML / Liquid layout through the safety sanitizer pipeline
        var sanitizedOverride = string.IsNullOrWhiteSpace(request.CustomLiquidOverride)
            ? null
            : _sanitizer.Sanitize(request.CustomLiquidOverride);

        var config = await _configs.GetAsync(tenantId, request.DocumentType, cancellationToken);
        if (config is null)
        {
            config = TenantDocumentConfiguration.Create(
                tenantId: tenantId,
                documentType: request.DocumentType,
                activeTemplateId: request.ActiveTemplateId,
                customLiquidOverride: sanitizedOverride,
                themePrimaryHex: request.ThemePrimaryHex,
                themeSecondaryHex: request.ThemeSecondaryHex,
                logoUrl: request.LogoUrl,
                showLogo: request.ShowLogo,
                footerNotes: request.FooterNotes);

            await _configs.AddAsync(config, cancellationToken);
        }
        else
        {
            config.UpdateConfiguration(
                activeTemplateId: request.ActiveTemplateId,
                customLiquidOverride: sanitizedOverride,
                themePrimaryHex: request.ThemePrimaryHex,
                themeSecondaryHex: request.ThemeSecondaryHex,
                logoUrl: request.LogoUrl,
                showLogo: request.ShowLogo,
                footerNotes: request.FooterNotes);

            await _configs.UpdateAsync(config, cancellationToken);
        }

        return Result<TenantDocumentConfigurationDto>.Success(
            TemplateMappers.ToDto(config, template.Name));
    }
}
