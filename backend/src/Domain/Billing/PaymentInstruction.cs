using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// Platform-level payment accounts and support contact displayed dynamically in client apps.
/// The SuperAdmin edits these via the Back-Office portal anytime without rebuilding the app.
/// </summary>
public sealed class PaymentInstruction : Entity
{
    public static readonly Guid PlatformId = new("00000000-0000-0000-0000-000000000001");

    private PaymentInstruction()
    {
    }

    public PaymentInstruction(
        Guid id,
        string mpesaTill,
        string airtelMoney,
        string bankName,
        string bankAccountNumber,
        string bankAccountName,
        string whatsAppContact,
        string notes)
        : base(id)
    {
        MpesaTill = mpesaTill;
        AirtelMoney = airtelMoney;
        BankName = bankName;
        BankAccountNumber = bankAccountNumber;
        BankAccountName = bankAccountName;
        WhatsAppContact = whatsAppContact;
        Notes = notes;
    }

    public string MpesaTill { get; private set; } = string.Empty;
    public string AirtelMoney { get; private set; } = string.Empty;
    public string BankName { get; private set; } = string.Empty;
    public string BankAccountNumber { get; private set; } = string.Empty;
    public string BankAccountName { get; private set; } = string.Empty;
    public string WhatsAppContact { get; private set; } = string.Empty;
    public string Notes { get; private set; } = string.Empty;

    public static PaymentInstruction CreateDefault()
        => new(
            PlatformId,
            mpesaTill: "5523412",
            airtelMoney: "",
            bankName: "CRDB Bank",
            bankAccountNumber: "015200000000",
            bankAccountName: "Jolinx Technologies Ltd",
            whatsAppContact: "+255700000000",
            notes: "Tuma ujumbe WhatsApp au piga simu baada ya kufanya malipo.");

    public void Update(
        string mpesaTill,
        string airtelMoney,
        string bankName,
        string bankAccountNumber,
        string bankAccountName,
        string whatsAppContact,
        string notes)
    {
        MpesaTill = mpesaTill?.Trim() ?? string.Empty;
        AirtelMoney = airtelMoney?.Trim() ?? string.Empty;
        BankName = bankName?.Trim() ?? string.Empty;
        BankAccountNumber = bankAccountNumber?.Trim() ?? string.Empty;
        BankAccountName = bankAccountName?.Trim() ?? string.Empty;
        WhatsAppContact = whatsAppContact?.Trim() ?? string.Empty;
        Notes = notes?.Trim() ?? string.Empty;
    }
}
