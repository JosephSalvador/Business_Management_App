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
        DateTime? expiresAtUtc,
        Guid? targetTenantId = null,
        string? planCode = null)
        : base(id)
    {
        Code = code;
        ValueDays = valueDays;
        IssuerTenantId = issuerTenantId;
        IssuedByUserId = issuedByUserId;
        ExpiresAtUtc = expiresAtUtc;
        TargetTenantId = targetTenantId;
        PlanCode = planCode;
    }

    public string Code { get; private set; }
    public int ValueDays { get; private set; }
    public Guid? IssuerTenantId { get; private set; }
    public Guid? IssuedByUserId { get; private set; }
    public VoucherStatus Status { get; private set; } = VoucherStatus.Issued;
    public Guid? RedeemedByTenantId { get; private set; }
    public DateTime? RedeemedAtUtc { get; private set; }
    public DateTime? ExpiresAtUtc { get; private set; }
    public Guid? TargetTenantId { get; private set; }
    public string? PlanCode { get; private set; }

    public static Voucher Create(
        Guid? issuerTenantId,
        Guid? issuedByUserId,
        string code,
        int valueDays,
        DateTime? expiresAtUtc = null,
        Guid? targetTenantId = null,
        string? planCode = null)
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
            expiresAtUtc?.ToUniversalTime(),
            targetTenantId,
            planCode?.Trim());
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

        if (TargetTenantId is not null && TargetTenantId.Value != tenantId)
        {
            throw new InvalidOperationException("This voucher was issued for a different workspace.");
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

/// <summary>CSPRNG-based voucher code generation, Luhn-32 checksum and normalization.</summary>
public static class VoucherCodes
{
    // Unambiguous when read over the phone/mobile: no 0/O, 1/I.
    private const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const int TotalChars = 12; // 11 payload chars + 1 check digit
    private const int Groups = 3;
    private const int CharsPerGroup = 4;

    public static string Generate()
    {
        // Generate 11 random bytes for payload
        var bytes = RandomNumberGenerator.GetBytes(TotalChars - 1);
        var payloadChars = new char[TotalChars - 1];
        var sum = 0;

        for (var i = 0; i < TotalChars - 1; i++)
        {
            var charIdx = bytes[i] % Alphabet.Length;
            payloadChars[i] = Alphabet[charIdx];
            sum += charIdx * (i + 1);
        }

        var checkChar = Alphabet[sum % Alphabet.Length];

        // Format as XXXX-XXXX-XXXX
        var formatted = new char[TotalChars + (Groups - 1)];
        var srcIdx = 0;
        var destIdx = 0;

        for (var g = 0; g < Groups; g++)
        {
            if (g > 0)
            {
                formatted[destIdx++] = '-';
            }

            for (var c = 0; c < CharsPerGroup; c++)
            {
                if (srcIdx < TotalChars - 1)
                {
                    formatted[destIdx++] = payloadChars[srcIdx++];
                }
                else
                {
                    formatted[destIdx++] = checkChar;
                }
            }
        }

        return new string(formatted);
    }

    /// <summary>
    /// Validates whether a normalized code satisfies the self-verifying Luhn-32 checksum.
    /// Rejects random guessing in-memory without contacting the database.
    /// </summary>
    public static bool IsValidChecksum(string code)
    {
        if (string.IsNullOrWhiteSpace(code)) return false;

        var clean = code.Replace("-", string.Empty).Replace(" ", string.Empty).ToUpperInvariant();
        if (clean.Length != TotalChars) return false;

        var sum = 0;
        for (var i = 0; i < TotalChars - 1; i++)
        {
            var idx = Alphabet.IndexOf(clean[i]);
            if (idx < 0) return false;
            sum += idx * (i + 1);
        }

        var expectedCheckChar = Alphabet[sum % Alphabet.Length];
        return clean[^1] == expectedCheckChar;
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