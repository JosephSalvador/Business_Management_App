namespace BusinessOS.Domain.Invoicing;

public enum CustomerInvoiceStatus
{
    Unpaid = 0,
    PartiallyPaid = 1,
    Paid = 2,
    Void = 3,
}
