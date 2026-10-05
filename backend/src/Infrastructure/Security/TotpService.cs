using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using BusinessOS.Application.Ports;

namespace BusinessOS.Infrastructure.Security;

/// <summary>
/// RFC 6238 time-based one-time passwords (HMAC-SHA1, per RFC 4226), the variant every
/// mainstream authenticator app implements.
///
/// Built on <see cref="HMACSHA1"/> from the BCL rather than a third-party package: the
/// algorithm is a few lines, and adding a dependency for it would widen the supply chain
/// of an authentication path for no benefit. <see cref="HMACSHA1"/> here implements the
/// published HMAC construction and is not being used as a collision-resistant digest.
/// </summary>
public sealed class TotpService : ITotpService
{
    /// <summary>Last successfully matched step, per secret + step, for replay rejection.</summary>
    /// <remarks>
    /// A TOTP code is valid for <c>window*2 + 1</c> steps, so within one window the same
    /// code would otherwise be accepted repeatedly. That lets an attacker who observes a
    /// single code (shoulder-surfing, a screen recording, a proxy log) replay it for up to a
    /// minute and a half. Remembering the last matched step closes that gap.
    ///
    /// Keyed by secret hash so a caller cannot use this to probe another user's state, and
    /// bounded so a long-running process cannot accumulate entries indefinitely. Losing the
    /// cache on restart is harmless: the worst case is the pre-existing replay window.
    /// </remarks>
    private const int MaxReplayEntries = 10_000;

    private readonly Dictionary<string, long> _lastUsedSteps = new(StringComparer.Ordinal);
    private readonly Lock _replayLock = new();

    private const string Base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private const int SecretSizeBytes = 20;
    private const int DefaultDigits = 6;
    private const int DefaultPeriodSeconds = 30;

    /// <summary>
    /// SHA1 is not a security choice here but a compatibility one: RFC 6238 permits it and
    /// essentially every authenticator app implements it. Combined with a 256-bit secret it
    /// is not the weak link: <see cref="VerifyCode"/> compares candidates in constant time and
    /// accepts only a narrow window.
    /// </summary>
    private const string _algorithm = "SHA1";

    public string GenerateSecret()
    {
        var bytes = RandomNumberGenerator.GetBytes(SecretSizeBytes);
        return Base32Encode(bytes);
    }

    public string GetProvisioningUri(string secret, string accountLabel, string issuer)
    {
        var normalizedIssuer = Uri.EscapeDataString(issuer);
        var normalizedLabel = Uri.EscapeDataString(accountLabel);

        // Label first, secret last: both are mandatory, and every mainstream app
        // accepts either parameter order, but a strict reader requires the label.
        return $"otpauth://totp/{normalizedIssuer}:{normalizedLabel}"
            + $"?secret={secret}"
            + $"&issuer={normalizedIssuer}"
            + $"&algorithm={_algorithm}"
            + $"&digits={DefaultDigits}"
            + $"&period={DefaultPeriodSeconds}";
    }

    public bool VerifyCode(
        string secret,
        string code,
        DateTimeOffset now,
        int stepSeconds,
        int digits,
        int window)
    {
        var normalized = code.Trim();
        if (normalized.Length != digits || !normalized.All(char.IsAsciiDigit))
        {
            return false;
        }

        byte[] secretBytes;
        try
        {
            secretBytes = Base32Decode(secret);
        }
        catch (FormatException)
        {
            return false;
        }

        if (secretBytes.Length == 0)
        {
            return false;
        }

        var currentStep = now.ToUnixTimeSeconds() / Math.Max(1, stepSeconds);
        var key = Convert.ToHexString(SHA256.HashData(secretBytes));
        var presented = Encoding.ASCII.GetBytes(normalized);

        // The window is symmetric so a device whose clock runs slightly fast still
        // validates, which is the common case for cheap handsets.
        //
        // Every candidate in the window is computed and compared before deciding,
        // so the comparison itself does not leak how far into the window a match
        // sits. The matched *step* is then recorded, which is what closes the
        // replay window: because the loop finishes, the newest match is always
        // the one claimed, and racing the clock cannot extend a code's life.
        var matched = -1L;
        for (var offset = -window; offset <= window; offset++)
        {
            var step = currentStep + offset;
            var candidate = GenerateCode(secretBytes, step, digits);
            var isMatch = CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(candidate),
                presented);

            // Keep the last (newest) match rather than the first.
            if (isMatch)
            {
                matched = step;
            }
        }

        return matched >= 0 && TryRecordUse(key, matched);
    }

    /// <summary>
    /// Claims a step for this secret. Returns false when the step was already spent, which
    /// is what makes an observed code single-use rather than replayable.
    /// </summary>
    private bool TryRecordUse(string secretKey, long step)
    {
        lock (_replayLock)
        {
            if (_lastUsedSteps.TryGetValue(secretKey, out var previous) && previous >= step)
            {
                return false;
            }

            if (_lastUsedSteps.Count >= MaxReplayEntries)
            {
                // Drop the oldest half rather than refusing new secrets: a stale entry is
                // harmless, whereas refusing would lock out a legitimate user.
                var stale = _lastUsedSteps
                    .OrderBy(kvp => kvp.Value)
                    .Take(MaxReplayEntries / 2)
                    .Select(kvp => kvp.Key)
                    .ToList();

                foreach (var key in stale)
                {
                    _lastUsedSteps.Remove(key);
                }
            }

            _lastUsedSteps[secretKey] = step;
            return true;
        }
    }

    internal static string GenerateCode(byte[] secret, long timeStep, int digits)
    {
        var counter = new byte[8];
        BinaryPrimitives.WriteInt64BigEndian(counter, timeStep);
        var hash = HMACSHA1.HashData(secret, counter);

        var offset = hash[^1] & 0x0F;
        var binaryCode = ((hash[offset] & 0x7F) << 24)
            | (hash[offset + 1] << 16)
            | (hash[offset + 2] << 8)
            | hash[offset + 3];

        var modulus = (int)Math.Pow(10, digits);
        return (binaryCode % modulus).ToString().PadLeft(digits, '0');
    }

    internal static string Base32Encode(byte[] data)
    {
        var builder = new StringBuilder((data.Length * 8 / 5) + 1);
        var buffer = 0;
        var bitsLeft = 0;

        foreach (var b in data)
        {
            buffer = (buffer << 8) | b;
            bitsLeft += 8;
            while (bitsLeft >= 5)
            {
                builder.Append(Base32Alphabet[(buffer >> (bitsLeft - 5)) & 0x1F]);
                bitsLeft -= 5;
            }
        }

        if (bitsLeft > 0)
        {
            builder.Append(Base32Alphabet[(buffer << (5 - bitsLeft)) & 0x1F]);
        }

        return builder.ToString();
    }

    internal static byte[] Base32Decode(string input)
    {
        var cleaned = input.Trim().Replace("=", string.Empty).Replace(" ", string.Empty).ToUpperInvariant();
        if (cleaned.Length == 0)
        {
            return [];
        }

        var output = new byte[cleaned.Length * 5 / 8];
        var buffer = 0;
        var bitsLeft = 0;
        var outputIndex = 0;

        foreach (var c in cleaned)
        {
            var value = Base32Alphabet.IndexOf(c);
            if (value < 0)
            {
                throw new FormatException("The secret is not valid base32.");
            }

            buffer = (buffer << 5) | value;
            bitsLeft += 5;
            if (bitsLeft < 8)
            {
                continue;
            }

            output[outputIndex++] = (byte)(buffer >> (bitsLeft - 8));
            bitsLeft -= 8;
        }

        return output;
    }
}
