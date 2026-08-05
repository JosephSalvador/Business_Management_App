namespace BusinessOS.Application.Features.Auth.Dtos;

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTime AccessTokenExpiresAt,
    UserDto User);

public sealed record UserDto(
    Guid Id,
    Guid TenantId,
    string Email,
    string FullName,
    string? Phone,
    bool IsActive,
    bool EmailVerified,
    IReadOnlyList<string> Permissions);
