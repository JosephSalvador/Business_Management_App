using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// A system-level marketplace template available for all tenants to format their invoices
/// and delivery notes. Not scoped to any single tenant (system global data asset).
/// </summary>
public sealed class DocumentTemplate : AggregateRoot
{
    private DocumentTemplate(
        Guid id,
        string name,
        string? description,
        DocumentType documentType,
        string liquidLayout,
        string? thumbnailBase64,
        string engineVersion,
        bool isActive,
        bool isDefault,
        int displayOrder)
        : base(id)
    {
        Name = name;
        Description = description;
        DocumentType = documentType;
        LiquidLayout = liquidLayout;
        ThumbnailBase64 = thumbnailBase64;
        EngineVersion = engineVersion;
        IsActive = isActive;
        IsDefault = isDefault;
        DisplayOrder = displayOrder;
        CreatedAt = DateTime.UtcNow;
    }

    public string Name { get; private set; }
    public string? Description { get; private set; }
    public DocumentType DocumentType { get; private set; }
    public string LiquidLayout { get; private set; }
    public string? ThumbnailBase64 { get; private set; }
    public string EngineVersion { get; private set; }
    public bool IsActive { get; private set; }
    public bool IsDefault { get; private set; }
    public int DisplayOrder { get; private set; }

    public static DocumentTemplate Create(
        string name,
        DocumentType documentType,
        string liquidLayout,
        string? description = null,
        string? thumbnailBase64 = null,
        string engineVersion = "Fluid-v2.0",
        bool isActive = true,
        bool isDefault = false,
        int displayOrder = 0,
        Guid? id = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Template name is required.", nameof(name));
        }

        if (string.IsNullOrWhiteSpace(liquidLayout))
        {
            throw new ArgumentException("Liquid layout content is required.", nameof(liquidLayout));
        }

        return new DocumentTemplate(
            id: id.HasValue && id.Value != Guid.Empty ? id.Value : Guid.NewGuid(),
            name: name.Trim(),
            description: string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            documentType: documentType,
            liquidLayout: liquidLayout.Trim(),
            thumbnailBase64: thumbnailBase64?.Trim(),
            engineVersion: string.IsNullOrWhiteSpace(engineVersion) ? "Fluid-v2.0" : engineVersion.Trim(),
            isActive: isActive,
            isDefault: isDefault,
            displayOrder: displayOrder);
    }

    public void Update(
        string name,
        string liquidLayout,
        string? description = null,
        string? thumbnailBase64 = null,
        string? engineVersion = null,
        bool? isDefault = null,
        int? displayOrder = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Template name is required.", nameof(name));
        }

        if (string.IsNullOrWhiteSpace(liquidLayout))
        {
            throw new ArgumentException("Liquid layout content is required.", nameof(liquidLayout));
        }

        Name = name.Trim();
        LiquidLayout = liquidLayout.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        ThumbnailBase64 = thumbnailBase64?.Trim() ?? ThumbnailBase64;
        if (!string.IsNullOrWhiteSpace(engineVersion))
        {
            EngineVersion = engineVersion.Trim();
        }
        if (isDefault.HasValue)
        {
            IsDefault = isDefault.Value;
        }
        if (displayOrder.HasValue)
        {
            DisplayOrder = displayOrder.Value;
        }
        UpdatedAt = DateTime.UtcNow;
    }

    public void SetActive(bool isActive)
    {
        IsActive = isActive;
        UpdatedAt = DateTime.UtcNow;
    }
}
