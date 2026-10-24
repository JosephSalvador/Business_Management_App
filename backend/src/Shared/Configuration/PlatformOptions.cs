namespace BusinessOS.Shared.Configuration;

public sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    public string ConnectionString { get; set; } = string.Empty;
    public int MaxRetryCount { get; set; } = 3;
    public int CommandTimeoutSeconds { get; set; } = 30;
}

public sealed class RedisOptions
{
    public const string SectionName = "Redis";

    public bool Enabled { get; set; }
    public string ConnectionString { get; set; } = string.Empty;
    public string InstanceName { get; set; } = "businessos:";
}

public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 587;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string From { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public bool UseStartTls { get; set; } = true;
}

public sealed class SmsOptions
{
    public const string SectionName = "Sms";

    public string Provider { get; set; } = "Logging";
    public string ApiKey { get; set; } = string.Empty;
    public string SenderId { get; set; } = string.Empty;
}

public sealed class StorageOptions
{
    public const string SectionName = "Storage";

    public string Provider { get; set; } = "Local";
    public string LocalRootPath { get; set; } = "storage";
    public string PublicBaseUrl { get; set; } = string.Empty;
    public string Endpoint { get; set; } = string.Empty;
    public string AccessKey { get; set; } = string.Empty;
    public string SecretKey { get; set; } = string.Empty;
    public string Bucket { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public bool UseHttps { get; set; }
    public string ConnectionString { get; set; } = string.Empty;
    public string ContainerName { get; set; } = "uploads";
}

public sealed class PaymentsOptions
{
    public const string SectionName = "Payments";

    public string Provider { get; set; } = "Logging";
    public string ApiKey { get; set; } = string.Empty;
    public string WebhookSecret { get; set; } = string.Empty;
    public string Currency { get; set; } = "TZS";
}

public sealed class CorsOptions
{
    public const string SectionName = "Cors";

    public string[] AllowedOrigins { get; set; } = Array.Empty<string>();
}

public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    public int AuthWindowSeconds { get; set; } = 60;
    public int AuthPermitLimit { get; set; } = 10;
    public int GlobalPermitLimit { get; set; } = 200;
    public int GlobalWindowSeconds { get; set; } = 60;
}

public sealed class SecurityOptions
{
    public const string SectionName = "Security";

    public int MaxFailedLoginAttempts { get; set; } = 5;
    public int LockoutDurationMinutes { get; set; } = 15;
    public int VerificationCodeTtlMinutes { get; set; } = 1440;
    public int VerificationMaxAttempts { get; set; } = 5;
    public int VerificationResendCooldownSeconds { get; set; } = 60;
    public int PasswordResetCodeTtlMinutes { get; set; } = 30;
    public int PasswordResetMaxAttempts { get; set; } = 5;
    public int PasswordResetResendCooldownSeconds { get; set; } = 60;
    public int InvitationCodeTtlHours { get; set; } = 72;
    public int InvitationMaxAttempts { get; set; } = 5;
    public int TwoFactorChallengeMinutes { get; set; } = 5;
    public int TwoFactorDigits { get; set; } = 6;
    public int TwoFactorStepSeconds { get; set; } = 30;
    public int TwoFactorWindow { get; set; } = 1;
    public int TwoFactorRecoveryCodeCount { get; set; } = 10;
    public bool TwoFactorRequiredForOwners { get; set; } = true;

    /// <summary>
    /// Wrong codes tolerated per challenge before it is spent. Separate from
    /// <see cref="MaxFailedLoginAttempts"/> so a stolen challenge token cannot be used to
    /// iterate all 10^6 TOTP values inside the challenge lifetime.
    /// </summary>
    public int TwoFactorMaxAttempts { get; set; } = 3;

    /// <summary>
    /// Key material for protecting second-factor secrets at rest. Falls back to the JWT
    /// secret when empty, so existing deployments need no new configuration; set it
    /// explicitly to keep MFA secrets independent of JWT rotation.
    /// </summary>
    public string TwoFactorEncryptionKey { get; set; } = string.Empty;
}
