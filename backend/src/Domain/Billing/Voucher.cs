using System.Security.Cryptography;
using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// A prepaid redemption code a tenant exchanges for paid access. Codes are generated
/// platform-side with a CSPRNG, sold by the owner, and redeemed by the tenant that paid.
/// Redemption maps 1:1 to a payment covering <see cref="ValueDays"/> of the Pro plan.
/// </summary>
public sealed class Voucher : AggregateRoot
{
    private Voucher(
        Guid id,
        string code,
        int valueDays,
        Guid? issuerTenantId,
        Guid? issuedByUserId,
        DateTime? expiresAtUtc)
        : base(id)
    {
        Code = code;
        ValueDays = valueDays;
        IssuerTenantId = issuerTenantId;
        IssuedByUserId = issuedByUserId;
        ExpiresAtUtc = expiresAtUtc;
    }

    public string Code { get; private set; }
    public int ValueDays { get; private set; }
    public Guid? IssuerTenantId { get; private set; }
    public Guid? IssuedByUserId { get; private set; }
    public VoucherStatus Status { get; private set; } = VoucherStatus.Issued;
    public Guid? RedeemedByTenantId { get; private set; }
    public DateTime? RedeemedAtUtc { get; private set; }
    public DateTime? ExpiresAtUtc { get; private set; }

    public static Voucher Create(
        Guid? issuerTenantId,
        Guid? issuedByUserId,
        string code,
        int valueDays,
        DateTime? expiresAtUtc = null)
    {
        if (valueDays < 1 || valueDays > 365)
        {
            throw new ArgumentOutOfRangeException(nameof(valueDays), "Voucher value must be between 1 and 365 days.");
        }

        return new Voucher(
            Guid.NewGuid(),
            VoucherCodes.Normalize(code),
            valueDays,
            issuerTenantId,
            issuedByUserId,
            expiresAtUtc?.ToUniversalTime());
    }

    public void Redeem(Guid tenantId, DateTime? nowUtc = null)
    {
        if (Status != VoucherStatus.Issued)
        {
            throw new InvalidOperationException("Only an issued voucher can be redeemed.");
        }

        if (ExpiresAtUtc is not null && ExpiresAtUtc <= (nowUtc ?? DateTime.UtcNow))
        {
            throw new InvalidOperationException("This voucher has expired.");
        }

        Status = VoucherStatus.Redeemed;
        RedeemedByTenantId = tenantId;
        RedeemedAtUtc = nowUtc ?? DateTime.UtcNow;
        AddDomainEvent(new VoucherRedeemedEvent(
            Guid.NewGuid(),
            RedeemedAtUtc.Value,
            Id,
            tenantId,
            Code,
            ValueDays));
    }

    /// <summary>
    /// Platform-level record that a batch of codes was sold by the owner. Raised once on the
    /// last code of the batch so the outbox carries exactly one audit/analytics event.
    /// </summary>
    public void RecordBatchIssued(IReadOnlyList<string> codesInBatch, Guid? issuedByUserId)
        => AddDomainEvent(new VouchersIssuedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            codesInBatch,
            ValueDays,
            issuedByUserId));
}

/// <summary>CSPRNG-based voucher code generation and normalization.</summary>
public static class VoucherCodes
{
    // Unambiguous when read over the phone/mobile: no 0/O, 1/I.
    private const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const int Groups = 3;
    private const int CharsPerGroup = 4;

    public static string Generate()
    {
        var bytes = RandomNumberGenerator.GetBytes(Groups * CharsPerGroup);
        var chars = new char[Groups * CharsPerGroup + (Groups - 1)];
        var charIndex = 0;
        for (var i = 0; i < Groups; i++)
        {
            if (i > 0)
            {
                chars[charIndex++] = '-';
            }

            for (var j = 0; j < CharsPerGroup; j++)
            {
                chars[charIndex++] = Alphabet[bytes[i * CharsPerGroup + j] % Alphabet.Length];
            }
        }

        return new string(chars);
    }

    public static string Normalize(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("A voucher code is required.", nameof(code));
        }

        return code.Trim().ToUpperInvariant();
    }
}