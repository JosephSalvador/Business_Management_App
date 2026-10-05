using System.Security.Cryptography;
using System.Text;

namespace BusinessOS.Application.Features.Auth.Services;

/// <summary>
/// Hashing and code-shape helpers for second-factor credentials. Mirrors
/// <see cref="EmailVerificationService"/>: raw values are lowercased hex SHA-256 digests,
/// so a leaked database row cannot be replayed against the API.
/// </summary>
public static class TwoFactorSecretService
{
    /// <summary>Lowercase hex SHA-256 of the normalized recovery code.</summary>
    public static string HashRecoveryCode(string code)
    {
        var normalized = NormalizeRecoveryCode(code);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized))).ToLowerInvariant();
    }

    /// <summary>
    /// Recovery codes are compared case-insensitively with surrounding whitespace removed,
    /// so a user transcribing one from a printout is not defeated by their own formatting.
    /// </summary>
    public static string NormalizeRecoveryCode(string code) => code.Trim().Replace("-", string.Empty).ToLowerInvariant();

    public static bool IsWellFormedRecoveryCode(string code)
    {
        var normalized = NormalizeRecoveryCode(code);
        if (normalized.Length is not (8 or 10))
        {
            return false;
        }

        return normalized.All(char.IsAsciiLetterOrDigit);
    }

    public static bool IsWellFormedTotpCode(string code, int digits)
    {
        var trimmed = code.Trim();
        return trimmed.Length == digits && trimmed.All(char.IsAsciiDigit);
    }
}
