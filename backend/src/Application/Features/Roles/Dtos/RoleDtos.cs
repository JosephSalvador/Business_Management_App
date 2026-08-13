namespace BusinessOS.Application.Features.Roles.Dtos;

public sealed record RoleDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    bool IsSystem,
    IReadOnlyList<string> PermissionNames,
    DateTime CreatedAt);

public sealed record PermissionDto(
    string Name,
    string? Description);
