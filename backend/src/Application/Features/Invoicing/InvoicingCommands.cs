using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Commands;

public static class CustomerInvoiceMappers
{
    public static CustomerInvoiceDto ToDto(CustomerInvoice invoice) => new(
        invoice.Id,
        invoice.Number,
        invoice.CustomerId,
        invoice.CustomerName,
        invoice.Currency,
        invoice.IssueDate,
        invoice.DueDate,
        invoice.Notes,
        invoice.Status,
        invoice.Subtotal,
        invoice.TaxAmount,
        invoice.TotalAmount,
        invoice.AmountPaid,
        invoice.BalanceDue,
        invoice.PaymentMethod,
        invoice.PaymentReference,
        invoice.PaidAtUtc,
        invoice.VoidedAtUtc,
        invoice.Lines
            .OrderBy(line => line.OrderIndex)
            .Select(line => new CustomerInvoiceLineDto(
                line.Id, line.Description, line.Quantity, line.UnitPrice,
                line.TaxRatePercent, line.LineTotal, line.TaxAmount,
                line.UnitOfMeasure, line.DiscountAmount))
            .ToList(),
        invoice.CreatedAt,
        invoice.DocumentTitle,
        invoice.ReferenceNumber,
        invoice.PaymentTerms,
        invoice.CustomerAttention,
        invoice.CustomerPhone,
        invoice.CustomerEmail,
        invoice.CustomerAddress,
        invoice.CustomerTin,
        invoice.DiscountAmount,
        invoice.PaymentInstructions,
        invoice.AuthorizedSignatoryName,
        invoice.AuthorizedSignatoryTitle);

    public static CustomerInvoiceSummaryDto ToSummary(CustomerInvoice invoice) => new(
        invoice.Id,
        invoice.Number,
        invoice.CustomerId,
        invoice.CustomerName,
        invoice.Status,
        invoice.IssueDate,
        invoice.DueDate,
        invoice.TotalAmount,
        invoice.AmountPaid,
        invoice.BalanceDue,
        invoice.CreatedAt,
        invoice.DocumentTitle,
        invoice.ReferenceNumber,
        invoice.Currency);
}

// ── Create Customer Invoice ─────────────────────────────────────────
public sealed record CustomerInvoiceLineRequest(
    string Description,
    decimal Quantity,
    decimal UnitPrice,
    decimal TaxRatePercent = 0m,
    string UnitOfMeasure = "Pcs",
    decimal DiscountAmount = 0m);

public sealed record CreateCustomerInvoiceCommand(
    IReadOnlyList<CustomerInvoiceLineRequest> Lines,
    Guid? CustomerId = null,
    string Currency = "TZS",
    DateTime? IssueDate = null,
    DateTime? DueDate = null,
    string? Notes = null,
    string? DocumentTitle = null,
    string? ReferenceNumber = null,
    string? PaymentTerms = null,
    string? CustomerName = null,
    string? CustomerAttention = null,
    string? CustomerPhone = null,
    string? CustomerEmail = null,
    string? CustomerAddress = null,
    string? CustomerTin = null,
    decimal DiscountAmount = 0m,
    decimal InitialAmountPaid = 0m,
    string? PaymentMethod = null,
    string? PaymentReference = null,
    string? PaymentInstructions = null,
    string? AuthorizedSignatoryName = null,
    string? AuthorizedSignatoryTitle = null,
    Guid? Id = null)
    : IRequest<Result<CustomerInvoiceDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateCustomerInvoiceCommandHandler
    : IRequestHandler<CreateCustomerInvoiceCommand, Result<CustomerInvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;
    private readonly ICustomerRepository _customers;
    private readonly IInvoiceNumberSequenceService _numbers;

    public CreateCustomerInvoiceCommandHandler(
        ITenantContext tenantContext,
        ICustomerInvoiceRepository invoices,
        ICustomerRepository customers,
        IInvoiceNumberSequenceService numbers)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
        _customers = customers;
        _numbers = numbers;
    }

    public async Task<Result<CustomerInvoiceDto>> Handle(
        CreateCustomerInvoiceCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var now = DateTime.UtcNow;

        if (command.Id is { } explicitId && explicitId != Guid.Empty)
        {
            var existing = await _invoices.GetByIdAsync(tenantId, explicitId, cancellationToken);
            if (existing is not null)
            {
                return Result.Success(CustomerInvoiceMappers.ToDto(existing));
            }
        }

        string? customerName = command.CustomerName;
        string? customerAttention = command.CustomerAttention;
        string? customerPhone = command.CustomerPhone;
        string? customerEmail = command.CustomerEmail;
        string? customerAddress = command.CustomerAddress;
        string? customerTin = command.CustomerTin;

        if (command.CustomerId is { } customerId)
        {
            var customer = await _customers.GetByIdAsync(tenantId, customerId, cancellationToken);
            if (customer is null)
            {
                return Error.NotFound("Customer not found.");
            }

            if (string.IsNullOrWhiteSpace(customerName)) customerName = customer.Name;
            if (string.IsNullOrWhiteSpace(customerAttention)) customerAttention = customer.ContactName;
            if (string.IsNullOrWhiteSpace(customerPhone)) customerPhone = customer.Phone;
            if (string.IsNullOrWhiteSpace(customerEmail)) customerEmail = customer.Email;
            if (string.IsNullOrWhiteSpace(customerAddress)) customerAddress = customer.Address;
            if (string.IsNullOrWhiteSpace(customerTin)) customerTin = customer.Tin;
        }

        if (command.Lines is null || command.Lines.Count == 0)
        {
            return Error.Validation("An invoice needs at least one line.");
        }

        if (command.Lines.Count > 200)
        {
            return Error.Validation("An invoice cannot have more than 200 lines.");
        }

        var specs = command.Lines
            .Select(line => new CustomerInvoiceLineSpec(
                line.Description,
                line.Quantity,
                line.UnitPrice,
                line.TaxRatePercent,
                line.UnitOfMeasure,
                line.DiscountAmount))
            .ToList();

        var number = await _numbers.NextAsync(
            tenantId, DocumentKind.CustomerInvoice, command.IssueDate ?? now, cancellationToken);

        CustomerInvoice invoice;
        try
        {
            invoice = CustomerInvoice.Create(
                tenantId,
                number,
                specs,
                command.CustomerId,
                customerName,
                command.Currency,
                command.IssueDate,
                command.DueDate,
                command.Notes,
                now,
                command.DocumentTitle,
                command.ReferenceNumber,
                command.PaymentTerms,
                customerAttention,
                customerPhone,
                customerEmail,
                customerAddress,
                customerTin,
                command.DiscountAmount,
                command.PaymentInstructions,
                command.AuthorizedSignatoryName,
                command.AuthorizedSignatoryTitle,
                command.Id);

            if (command.InitialAmountPaid > 0)
            {
                var deposit = Math.Min(command.InitialAmountPaid, invoice.TotalAmount);
                if (deposit > 0)
                {
                    invoice.RecordPayment(
                        deposit,
                        command.PaymentMethod,
                        command.PaymentReference,
                        _tenantContext.UserId,
                        now);
                }
            }
        }
        catch (ArgumentException exception)
        {
            return Error.Validation(exception.Message);
        }

        await _invoices.AddAsync(invoice, cancellationToken);
        return Result.Success(CustomerInvoiceMappers.ToDto(invoice));
    }
}

// ── Record Customer Invoice Payment ──────────────────────────────────
public sealed record RecordCustomerInvoicePaymentCommand(
    Guid Id,
    decimal Amount,
    string? Method = null,
    string? Reference = null)
    : IRequest<Result<CustomerInvoiceDto>>, IRequiresTenantAdvisoryLock;

public sealed class RecordCustomerInvoicePaymentCommandHandler
    : IRequestHandler<RecordCustomerInvoicePaymentCommand, Result<CustomerInvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;

    public RecordCustomerInvoicePaymentCommandHandler(
        ITenantContext tenantContext, ICustomerInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<CustomerInvoiceDto>> Handle(
        RecordCustomerInvoicePaymentCommand command, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetByIdAsync(
            _tenantContext.TenantId, command.Id, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        if (invoice.Status is CustomerInvoiceStatus.Paid or CustomerInvoiceStatus.Void)
        {
            return Error.Conflict($"This invoice is already {invoice.Status}.");
        }

        try
        {
            invoice.RecordPayment(
                command.Amount,
                command.Method,
                command.Reference,
                _tenantContext.UserId);
        }
        catch (ArgumentException exception)
        {
            return Error.Validation(exception.Message);
        }

        await _invoices.UpdateAsync(invoice, cancellationToken);
        return Result.Success(CustomerInvoiceMappers.ToDto(invoice));
    }
}

// ── Void Customer Invoice ────────────────────────────────────────────
public sealed record VoidCustomerInvoiceCommand(Guid Id)
    : IRequest<Result<CustomerInvoiceDto>>, IRequiresTenantAdvisoryLock;

public sealed class VoidCustomerInvoiceCommandHandler
    : IRequestHandler<VoidCustomerInvoiceCommand, Result<CustomerInvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;

    public VoidCustomerInvoiceCommandHandler(
        ITenantContext tenantContext, ICustomerInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<CustomerInvoiceDto>> Handle(
        VoidCustomerInvoiceCommand command, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetByIdAsync(
            _tenantContext.TenantId, command.Id, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        if (invoice.Status == CustomerInvoiceStatus.Void)
        {
            return Error.Conflict("This invoice is already void.");
        }

        if (invoice.Status == CustomerInvoiceStatus.Paid)
        {
            return Error.Conflict("A fully paid invoice cannot be voided.");
        }

        invoice.Void(_tenantContext.UserId);
        await _invoices.UpdateAsync(invoice, cancellationToken);
        return Result.Success(CustomerInvoiceMappers.ToDto(invoice));
    }
}
