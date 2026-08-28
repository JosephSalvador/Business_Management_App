namespace BusinessOS.Application.Features.Catalog.Dtos;

public sealed record ProductCategoryDto(
    Guid Id,
    Guid TenantId,
    string Name,
    Guid? ParentId,
    bool IsActive,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record BrandDto(
    Guid Id,
    Guid TenantId,
    string Name,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record UnitOfMeasureDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string Abbreviation,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record TaxCategoryDto(
    Guid Id,
    string Code,
    string Name);
