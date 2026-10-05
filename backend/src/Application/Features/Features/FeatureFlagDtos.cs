namespace BusinessOS.Application.Features.Features;

public sealed record FeatureFlagDto(
    Guid Id, Guid TenantId, string Key, bool IsEnabled, string? Config, DateTime CreatedAt);
