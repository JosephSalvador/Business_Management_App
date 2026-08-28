using System.Security.Cryptography;
using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Jobs;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Services;

/// <summary>
/// Issues single-use email verification codes. Codes are cryptographically random,
/// stored only as SHA-256 hashes, expire after a configured TTL, and are delivered
/// exclusively through the outbox-backed email job queue — never in API responses
/// or logs. A resend inside the cooldown window is rejected with TooManyRequests.
/// </summary>
public sealed class EmailVerificationService
{
    public const string EmailSubject = "Thibitisha barua pepe yako — Business OS";

    private readonly IEmailVerificationCodeRepository _codes;
    private readonly IJobQueue _jobQueue;
    private readonly SecurityOptions _security;

    public EmailVerificationService(
        IEmailVerificationCodeRepository codes,
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
        var expiresAt = DateTime.UtcNow.AddMinutes(_security.VerificationCodeTtlMinutes);
        await _codes.AddAsync(
            EmailVerificationCode.Create(user.TenantId, user.Id, Hash(code), expiresAt),
            cancellationToken);

        var hours = Math.Max(1, _security.VerificationCodeTtlMinutes / 60);
        var body = $"""
            Habari {user.FullName},

            Namba yako ya kuthibitisha barua pepe ni: {code}

            Namba hii inatumika mara moja tu na inaisha baada ya saa {hours}.
            Kama huekuomba usajili huu, puuza barua pepe hii.

            — Timu ya Business OS
            """;
        await _jobQueue.EnqueueAsync(
            SendEmailJob.Create(user.TenantId, user.Email, EmailSubject, body),
            cancellationToken);
    }

    /// <summary>Returns the remaining cooldown for the user's most recent code, if any.</summary>
    public async Task<TimeSpan?> GetRemainingCooldownAsync(
        User user, CancellationToken cancellationToken)
    {
        var latest = await _codes.GetLatestForUserAsync(user.TenantId, user.Id, cancellationToken);
        if (latest is null)
        {
            return null;
        }

        var elapsed = DateTime.UtcNow - latest.CreatedAt;
        var cooldown = TimeSpan.FromSeconds(_security.VerificationResendCooldownSeconds);
        return elapsed >= cooldown ? null : cooldown - elapsed;
    }

    private static string GenerateCode()
        => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    public static string Hash(string code)
    {
        var bytes = SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(code.Trim()));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
