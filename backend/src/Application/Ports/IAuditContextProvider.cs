using BusinessOS.Shared.Audit;

namespace BusinessOS.Application.Ports;

public interface IAuditContextProvider
{
    Task<AuditContext> GetContextAsync(CancellationToken ct = default);
}
