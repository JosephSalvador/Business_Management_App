using System.Text.Json;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Receipts.Commands;

/// <summary>
/// Seeds the default thermal 80mm receipt layout for a tenant. Called during onboarding or
/// when a tenant first uses the POS. Idempotent: no-ops if the layout already exists.
/// </summary>
public sealed record SeedDefaultLayoutCommand : IRequest<Result<Guid>>;

public sealed class SeedDefaultLayoutCommandHandler : IRequestHandler<SeedDefaultLayoutCommand, Result<Guid>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReceiptLayoutRepository _layouts;

    public SeedDefaultLayoutCommandHandler(
        ITenantContext tenantContext,
        IReceiptLayoutRepository layouts)
    {
        _tenantContext = tenantContext;
        _layouts = layouts;
    }

    public async Task<Result<Guid>> Handle(SeedDefaultLayoutCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var existing = await _layouts.GetActiveAsync(tenantId, Thermal80mmDefaults.LayoutId, cancellationToken);
        if (existing is not null)
        {
            return existing.Id;
        }

        var layout = ReceiptLayout.Create(
            tenantId: tenantId,
            layoutId: Thermal80mmDefaults.LayoutId,
            paperWidth: "80mm",
            sections: JsonDocument.Parse(Thermal80mmDefaults.Sections),
            styling: JsonDocument.Parse(Thermal80mmDefaults.Styling));

        await _layouts.AddAsync(layout, cancellationToken);
        return layout.Id;
    }
}

/// <summary>
/// Default thermal 80mm layout definition. This is the canonical seed data for the most
/// common POS receipt format. The layout is versioned; changes produce a new version.
/// </summary>
public static class Thermal80mmDefaults
{
    public const string LayoutId = "thermal_80mm_default";

    public const string Sections = """
    [
        {"type":"reprintMarker","fields":[],"options":{"showWhenReprint":true}},
        {"type":"businessHeader","fields":["businessName","tin","address","phone"]},
        {"type":"receiptInfo","fields":["receiptNumber","timestamp"]},
        {"type":"divider","options":{"character":"-","count":32}},
        {"type":"items","fields":["productName","quantity","unitPrice","lineTotal"],"options":{"maxNameLength":20,"showDiscount":true}},
        {"type":"divider","options":{"character":"-","count":32}},
        {"type":"totals","fields":["subtotal","taxAmount","discount","grandTotal"]},
        {"type":"payments","fields":["paymentMethod","amountPaid","change"]},
        {"type":"fiscalInfo","fields":["fiscalHash","qrCode"],"options":{"showWhenAvailable":true}},
        {"type":"divider","options":{"character":"-","count":32}},
        {"type":"footer","fields":["thankYouMessage"]}
    ]
    """;

    public const string Styling = """
    {
        "fontFamily": "monospace",
        "fontSize": 13,
        "lineHeight": 1.35,
        "alignCenter": ["businessName", "receiptNumber", "thankYouMessage"]
    }
    """;
}
