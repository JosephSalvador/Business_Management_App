using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Crm;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Crm.Queries;

// ── List Customers ──────────────────────────────────────────────
public sealed record ListCustomersQuery(int Page, int PageSize, string? Search)
    : IRequest<Result<PagedCustomers>>, IRequiresTenantAdvisoryLock;

public sealed class ListCustomersQueryHandler
    : IRequestHandler<ListCustomersQuery, Result<PagedCustomers>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerRepository _customers;

    public ListCustomersQueryHandler(ITenantContext tenantContext, ICustomerRepository customers)
    {
        _tenantContext = tenantContext;
        _customers = customers;
    }

    public async Task<Result<PagedCustomers>> Handle(
        ListCustomersQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _customers.ListAsync(tenantId, query.Page, query.PageSize, query.Search, cancellationToken);
        var total = await _customers.CountAsync(tenantId, query.Search, cancellationToken);

        var dtos = items.Select(CustomerMappers.ToDto).ToList();
        return Result.Success(new PagedCustomers(dtos, total));
    }
}

// ── Get Customer ────────────────────────────────────────────────
public sealed record GetCustomerQuery(Guid CustomerId)
    : IRequest<Result<CustomerDto>>, IRequiresTenantAdvisoryLock;

public sealed class GetCustomerQueryHandler
    : IRequestHandler<GetCustomerQuery, Result<CustomerDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerRepository _customers;

    public GetCustomerQueryHandler(ITenantContext tenantContext, ICustomerRepository customers)
    {
        _tenantContext = tenantContext;
        _customers = customers;
    }

    public async Task<Result<CustomerDto>> Handle(
        GetCustomerQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var customer = await _customers.GetByIdAsync(tenantId, query.CustomerId, cancellationToken);
        if (customer is null) return Error.NotFound("Customer not found.");

        return Result.Success(CustomerMappers.ToDto(customer));
    }
}
