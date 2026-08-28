using System.Security.Cryptography;
using BusinessOS.Application.Jobs;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Services;

/// <summary>
/// Issues single-use password reset codes. Codes are cryptographically random,
/// stored only as SHA-256 hashes, expire after a short TTL, and are delivered
/// exclusively through the outbox-backed email job queue — never in API responses
/// or logs. A resend inside the cooldown window is rejected with TooManyRequests.
/// </summary>
public sealed class PasswordResetService
{
    public const string EmailSubject = "Weka upya neno la siri — Business OS";

    private readonly IPasswordResetCodeRepository _codes;
    private readonly IJobQueue _jobQueue;
    private readonly SecurityOptions _security;

    public PasswordResetService(
        IPasswordResetCodeRepository codes,
        IJobQueue jobQueue,
        IOptions<SecurityOptions> security)
    {
        _codes = codes;
        _jobQueue = jobQueue;
        _security = security.Value;
    }

    /// <summary>Invalidates any previous codes and emails a fresh one.</summary>
    public async Task IssueAsync(User user, CancellationToken cancellationToken)
    {
        await _codes.InvalidateAllForUserAsync(user.TenantId, user.Id, cancellationToken);

        var code = GenerateCode();
        var expiresAt = DateTime.UtcNow.AddMinutes(_security.PasswordResetCodeTtlMinutes);
        await _codes.AddAsync(
            PasswordResetCode.Create(user.TenantId, user.Id, Hash(code), expiresAt),
            cancellationToken);

        var body = $"""
            Habari {user.FullName},

            Namba yako ya kuweka upya neno la siri ni: {code}

            Namba hii inatumika mara moja tu na inaisha baada ya dakika {_security.PasswordResetCodeTtlMinutes}.
            Kama huekuomba kubadilisha neno la siri, puuza barua pepe hii.

            — Timu ya Business OS
            """;
        await _jobQueue.EnqueueAsync(
            SendEmailJob.Create(user.TenantId, user.Email, EmailSubject, body),
            cancellationToken);
    }

    /// <summary>Returns the remaining cooldown for the most recent code, if any.</summary>
    public async Task<TimeSpan?> GetRemainingCooldownAsync(
        User user, CancellationToken cancellationToken)
    {
        var latest = await _codes.GetLatestForUserAsync(user.TenantId, user.Id, cancellationToken);
        if (latest is null)
        {
            return null;
        }

        var elapsed = DateTime.UtcNow - latest.CreatedAt;
        var cooldown = TimeSpan.FromSeconds(_security.PasswordResetResendCooldownSeconds);
        return elapsed >= cooldown ? null : cooldown - elapsed;
    }

    public string Hash(string code) => CodeHasher.Hash(code);

    private static string GenerateCode()
        => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
}

/// <summary>Shared SHA-256 hashing for 6-digit codes (verification and reset).</summary>
public static class CodeHasher
{
    public static string Hash(string code)
    {
        var bytes = SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(code.Trim()));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}