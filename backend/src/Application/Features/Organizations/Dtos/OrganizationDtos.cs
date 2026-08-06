namespace BusinessOS.Application.Features.Organizations.Dtos;

public sealed record OrganizationDto(
    Guid Id,
    string Name,
    string? ContactEmail,
    string? ContactPhone,
    string? Address,
    string Currency,
    string? TaxId,
    bool IsActive);
