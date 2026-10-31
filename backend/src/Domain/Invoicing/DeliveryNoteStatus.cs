namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// Lifecycle of a delivery note: drafted in the office, dispatched with the vehicle, then
/// signed for by the receiver. A note can be cancelled until it has been delivered.
/// </summary>
public enum DeliveryNoteStatus
{
    Draft = 0,
    Dispatched = 1,
    Delivered = 2,
    Cancelled = 3,
}
