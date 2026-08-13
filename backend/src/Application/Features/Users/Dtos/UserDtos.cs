namespace BusinessOS.Application.Features.Users.Dtos;

public sealed record IdentityUserDto(
    Guid Id,
    Guid TenantId,
    string Email,
    string FullName,
    string? Phone,
    bool IsActive,
    bool EmailVerified,
    bool IsLockedOut,
    IReadOnlyList<Guid> RoleIds,
    IReadOnlyList<Guid> BranchIds,
    Guid? DefaultBranchId,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record UserBranchDto(
    Guid BranchId,
    string BranchName,
    string BranchCode,
    bool IsDefault);
