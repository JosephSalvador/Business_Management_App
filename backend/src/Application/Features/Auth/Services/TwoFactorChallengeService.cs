using System.Security.Cryptography;
using System.Text;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Services;

/// <summary>
/// Issues the short-lived second-factor challenge handed out when the password check passes
/// but the account has a factor pending, and verifies codes against a user's protected
/// secret.
///
/// The token is opaque random material whose SHA-256 hash is persisted as a
/// <see cref="TwoFactorChallenge"/>. An opaque value is used in preference to a signed
/// self-describing payload because the challenge must be single-use, which a stateless token
/// cannot be; see <see cref="TwoFactorChallenge"/> for the reasoning.
///
/// Each challenge token is fresh random material rather than anything derived from a
/// tenant-wide secret, so no extra configuration is needed for it to be unforgeable:
/// guessing 256 bits of entropy is the only way in.
/// </summary>
public sealed class TwoFactorChallengeService
{
    private readonly ISecretProtector _protector;
    private readonly ITotpService _totp;
    private readonly ITwoFactorChallengeRepository _challenges;
    private readonly SecurityOptions _security;

    public TwoFactorChallengeService(
        ISecretProtector protector,
        ITotpService totp,
        ITwoFactorChallengeRepository challenges,
        IOptions<SecurityOptions> security)
    {
        _protector = protector;
        _totp = totp;
        _challenges = challenges;
        _security = security.Value;
    }

    /// <summary>
    /// Creates a challenge for <paramref name="user"/> and returns the raw token. Only the
    /// hash is stored, so the caller must return the raw value to the client directly.
    /// </summary>
    public async Task<string> IssueAsync(User user, CancellationToken cancellationToken)
    {
        var raw = GenerateToken();
        await _challenges.AddAsync(
            TwoFactorChallenge.Create(
                user.TenantId,
                user.Id,
                Hash(raw),
                DateTime.UtcNow.AddMinutes(_security.TwoFactorChallengeMinutes)),
            cancellationToken);

        return raw;
    }

    /// <summary>
    /// Loads the challenge behind a presented token. Returns null when the token is unknown,
    /// expired, or already consumed, so a replay is indistinguishable from a typo and the
    /// client is told to sign in again.
    /// </summary>
    public Task<TwoFactorChallenge?> FindAsync(string challengeToken, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(challengeToken))
        {
            return Task.FromResult<TwoFactorChallenge?>(null);
        }

        return _challenges.GetByHashAsync(Hash(challengeToken), cancellationToken);
    }

    /// <summary>Verifies a TOTP code against the user's protected active secret.</summary>
    public bool VerifyCode(User user, string code)
    {
        if (user.TwoFactorSecret is null)
        {
            return false;
        }

        return VerifySecret(user.TwoFactorSecret, code);
    }

    /// <summary>
    /// Verifies a code against the <em>staged</em> secret during enrolment. Kept separate
    /// from <see cref="VerifyCode"/> so confirming cannot accidentally validate against an old
    /// active factor and silently leave the user holding a secret their authenticator never saw.
    /// </summary>
    public bool VerifyPendingCode(User user, string code)
    {
        if (user.TwoFactorPendingSecret is null)
        {
            return false;
        }

        return VerifySecret(user.TwoFactorPendingSecret, code);
    }

    private bool VerifySecret(string protectedSecret, string code)
    {
        string secret;
        try
        {
            secret = _protector.Unprotect(protectedSecret);
        }
        catch (Exception ex) when (ex is CryptographicException or FormatException or ArgumentException)
        {
            // An unreadable secret means the factor cannot be evaluated — usually because the
            // encryption key rotated. Treated as a failed verification rather than a 500 so
            // the user sees "wrong code" and can recover with a code or an admin reset,
            // instead of a 500 on every attempt.
            return false;
        }

        return _totp.VerifyCode(
            secret,
            code,
            DateTimeOffset.UtcNow,
            _security.TwoFactorStepSeconds,
            _security.TwoFactorDigits,
            _security.TwoFactorWindow);
    }

    /// <summary>
    /// Generates a fresh batch of distinct recovery codes. Callers persist only the hashes;
    /// the raw codes are returned to the client once and never stored.
    /// </summary>
    public IReadOnlyList<string> GenerateRecoveryCodes(int count)
    {
        var codes = new List<string>(count);
        var seen = new HashSet<string>(StringComparer.Ordinal);

        // Ambiguous glyphs (0/O, 1/I) are excluded so a code read off a printout is always
        // transcribable by someone looking at a damaged screen.
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

        while (codes.Count < count)
        {
            var builder = new StringBuilder(10);
            for (var i = 0; i < 10; i++)
            {
                builder.Append(alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)]);
            }

            if (seen.Add(builder.ToString()))
            {
                codes.Add(builder.ToString());
            }
        }

        return codes;
    }

    private static string GenerateToken()
        => Base64UrlEncode(RandomNumberGenerator.GetBytes(32));

    private static string Hash(string raw)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw))).ToLowerInvariant();

    private static string Base64UrlEncode(byte[] bytes)
        => Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
}
