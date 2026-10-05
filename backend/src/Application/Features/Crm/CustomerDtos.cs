namespace BusinessOS.Application.Features.Crm;

public sealed record CustomerDto(
    Guid Id, Guid TenantId, string Name, string? ContactName, string? Email,
    string? Phone, string? Address, string? Tin, bool IsVatRegistered,
    string? Notes, bool IsActive, DateTime CreatedAt);

public sealed record PagedCustomers(
    IReadOnlyList<CustomerDto> Items, int Total);
