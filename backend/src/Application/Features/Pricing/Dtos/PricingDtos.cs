using BusinessOS.Domain.Pricing;

namespace BusinessOS.Application.Features.Pricing.Dtos;

public sealed record PriceListDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string Currency,
    bool IsDefault,
    bool IsActive,
    DateTime? EffectiveFrom,
    DateTime? EffectiveTo,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record ProductPriceDto(
    Guid Id,
    Guid PriceListId,
    Guid ProductId,
    Guid? VariantId,
    Guid? BranchId,
    PriceType PriceType,
    decimal Price,
    string Currency,
    decimal MinQuantity,
    DateTime? EffectiveFrom,
    DateTime? EffectiveTo,
    bool IsActive);

public sealed record ProductPriceInputDto(
    Guid? Id,
    Guid ProductId,
    Guid? VariantId,
    Guid? BranchId,
    PriceType PriceType,
    decimal Price,
    string Currency,
    decimal MinQuantity,
    DateTime? EffectiveFrom,
    DateTime? EffectiveTo,
    bool IsActive = true);

public sealed record ResolvedPriceDto(
    decimal Price,
    string Currency,
    Guid PriceListId,
    PriceType PriceType,
    decimal MinQuantity);

public sealed record ResolvePriceLineDto(
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity);

public sealed record ResolvedLineDto(
    Guid ProductId,
    Guid? VariantId,
    decimal? Price,
    string? Currency,
    string? ErrorMessage);
