namespace BusinessOS.Application.Features.Branches.Dtos;

public sealed record BranchDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string Code,
    string Currency,
    string? Address,
    string? Phone,
    string? Email,
    bool IsActive,
    DateTime CreatedAt,
    DateTime? UpdatedAt);
