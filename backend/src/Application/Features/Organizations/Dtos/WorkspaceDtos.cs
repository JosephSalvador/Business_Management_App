namespace BusinessOS.Application.Features.Organizations.Dtos;

/// <summary>
/// A workspace the authenticated user may enter. The backend derives the list from the
/// JWT claims; the client never supplies tenant or role information. Shaped as a list so
/// multi-workspace support can be added without breaking the contract (today it holds
/// at most one entry because a user belongs to exactly one organization).
/// </summary>
public sealed record WorkspaceDto(
    Guid Id,
    string Name,
    string Currency,
    string CountryCode,
    string? BusinessType,
    bool OnboardingComplete,
    IReadOnlyList<string> Roles);
