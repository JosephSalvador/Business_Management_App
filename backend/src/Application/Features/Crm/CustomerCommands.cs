using BusinessOS.Application.Ports;
using BusinessOS.Domain.Crm;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Crm.Commands;

public static class CustomerMappers
{
    public static CustomerDto ToDto(Customer c) => new(
        c.Id, c.TenantId, c.Name, c.ContactName, c.Email, c.Phone,
        c.Address, c.Tin, c.Notes, c.IsActive, c.CreatedAt);
}

// ── Create Customer ─────────────────────────────────────────────
public sealed record CreateCustomerCommand(
    string Name, string? ContactName, string? Email, string? Phone,
    string? Address, string? Tin, string? Notes)
    : IRequest<Result<CustomerDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateCustomerCommandHandler
    : IRequestHandler<CreateCustomerCommand, Result<CustomerDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerRepository _customers;

    public CreateCustomerCommandHandler(ITenantContext tenantContext, ICustomerRepository customers)
    {
        _tenantContext = tenantContext;
        _customers = customers;
    }

    public async Task<Result<CustomerDto>> Handle(
        CreateCustomerCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        Customer customer;
        try
        {
            customer = Customer.Create(
                tenantId, command.Name, command.ContactName, command.Email,
                command.Phone, command.Address, command.Tin,
                false, command.Notes);
        }
        catch (ArgumentException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _customers.AddAsync(customer, cancellationToken);
        return Result.Success(CustomerMappers.ToDto(customer));
    }
}

// ── Update Customer ─────────────────────────────────────────────
public sealed record UpdateCustomerCommand(
    Guid CustomerId, string? Name, string? ContactName, string? Email,
    string? Phone, string? Address, string? Tin, string? Notes)
    : IRequest<Result<CustomerDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateCustomerCommandHandler
    : IRequestHandler<UpdateCustomerCommand, Result<CustomerDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerRepository _customers;

    public UpdateCustomerCommandHandler(ITenantContext tenantContext, ICustomerRepository customers)
    {
        _tenantContext = tenantContext;
        _customers = customers;
    }

    public async Task<Result<CustomerDto>> Handle(
        UpdateCustomerCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var customer = await _customers.GetByIdAsync(tenantId, command.CustomerId, cancellationToken);
        if (customer is null) return Error.NotFound("Customer not found.");

        customer.UpdateDetails(
            command.Name, command.ContactName, command.Email, command.Phone,
            command.Address, command.Tin, false, command.Notes);

        await _customers.UpdateAsync(customer, cancellationToken);
        return Result.Success(CustomerMappers.ToDto(customer));
    }
}
