namespace BusinessOS.Application.Ports;

public interface IPermissionService
{
    Task<IReadOnlyCollection<string>> GetPermissionsAsync(Guid userId, Guid tenantId, CancellationToken ct = default);
    Task InvalidateAsync(Guid userId, Guid tenantId, CancellationToken ct = default);
}
