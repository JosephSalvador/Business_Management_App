using System.Text.Json;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A reusable receipt layout definition stored as a small JSON configuration. Layouts describe
/// the structure (sections, fields, styling) of a receipt without storing the receipt itself.
/// Multiple sale formats (thermal 80mm, A4 invoice, PDF) can be served from one transaction
/// by applying different layouts. Versioned so that historical reprints use the exact layout
/// that was active at the time of sale.
/// </summary>
public sealed class ReceiptLayout : AggregateRoot
{
    private ReceiptLayout(
        Guid id,
        Guid tenantId,
        string layoutId,
        int version,
        string paperWidth,
        string? paperHeight,
        bool isActive,
        JsonDocument sections,
        JsonDocument? styling)
        : base(id)
    {
        TenantId = tenantId;
        LayoutId = layoutId;
        Version = version;
        PaperWidth = paperWidth;
        PaperHeight = paperHeight;
        IsActive = isActive;
        Sections = sections;
        Styling = styling;
    }

    public Guid TenantId { get; private set; }

    /// <summary>
    /// Logical layout identifier (e.g. "thermal_80mm_default"). Stable across versions.
    /// </summary>
    public string LayoutId { get; private set; }

    /// <summary>Monotonically increasing version number. Incremented on each layout change.</summary>
    public int Version { get; private set; }

    /// <summary>Paper width (e.g. "80mm", "A4").</summary>
    public string PaperWidth { get; private set; }

    /// <summary>Paper height; null for continuous-roll thermal printers.</summary>
    public string? PaperHeight { get; private set; }

    /// <summary>Only one active version per LayoutId at a time.</summary>
    public bool IsActive { get; private set; }

    /// <summary>JSON array of section definitions (type, fields, options).</summary>
    public JsonDocument Sections { get; private set; }

    /// <summary>Optional JSON styling (font sizes, margins, alignment).</summary>
    public JsonDocument? Styling { get; private set; }

    public static ReceiptLayout Create(
        Guid tenantId,
        string layoutId,
        string paperWidth,
        JsonDocument sections,
        JsonDocument? styling = null,
        string? paperHeight = null,
        bool isActive = true)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required.", nameof(tenantId));
        }

        if (string.IsNullOrWhiteSpace(layoutId))
        {
            throw new ArgumentException("A layout identifier is required.", nameof(layoutId));
        }

        if (string.IsNullOrWhiteSpace(paperWidth))
        {
            throw new ArgumentException("A paper width is required.", nameof(paperWidth));
        }

        if (sections is null)
        {
            throw new ArgumentException("Sections are required.", nameof(sections));
        }

        return new ReceiptLayout(
            Guid.NewGuid(),
            tenantId,
            layoutId.Trim(),
            version: 1,
            paperWidth.Trim(),
            Normalize(paperHeight),
            isActive,
            sections,
            styling);
    }

    /// <summary>
    /// Creates a new version of an existing layout. The old version is deactivated; the new
    /// one takes over as the active layout for this LayoutId.
    /// </summary>
    public ReceiptLayout Fork(JsonDocument newSections, JsonDocument? newStyling = null)
    {
        return new ReceiptLayout(
            Guid.NewGuid(),
            TenantId,
            LayoutId,
            Version + 1,
            PaperWidth,
            PaperHeight,
            isActive: true,
            newSections,
            newStyling ?? Styling);
    }

    public void Deactivate() => IsActive = false;

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
