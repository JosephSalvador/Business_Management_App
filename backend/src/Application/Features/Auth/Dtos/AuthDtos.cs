namespace BusinessOS.Application.Features.Auth.Dtos;

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTime AccessTokenExpiresAt,
    UserDto User);

/// <summary>
/// Discriminated login result. A successful password check is not yet a session when the
/// account has a second factor: <c>Status</c> is then <c>two_factor_required</c> and no
/// tokens are present. The account email is echoed so the client can resume the challenge
/// even when the user signed in with a phone number.
/// </summary>
public sealed record LoginResponse(
    string Status,
    AuthResponse? Tokens,
    string? ChallengeToken,
    string? Email)
{
    public bool RequiresTwoFactor => Status == AuthConstants.LoginStatusTwoFactorRequired;

    public static LoginResponse Authenticated(AuthResponse tokens)
        => new(AuthConstants.LoginStatusAuthenticated, tokens, null, tokens.User.Email);

    public static LoginResponse TwoFactorRequired(string challengeToken, string email)
        => new(AuthConstants.LoginStatusTwoFactorRequired, null, challengeToken, email);
}

public sealed record UserDto(
    Guid Id,
    Guid TenantId,
    string Email,
    string FullName,
    string? Phone,
    bool IsActive,
    bool EmailVerified,
    IReadOnlyList<string> Permissions)
{
    public bool TwoFactorEnabled { get; init; }
}

public sealed record CurrentUserDto(
    Guid Id,
    Guid TenantId,
    string Email,
    string FullName,
    string? Phone,
    bool IsActive,
    bool EmailVerified,
    IReadOnlyList<string> Permissions,
    string TenantName,
    IReadOnlyList<string> RoleNames)
{
    public bool TwoFactorEnabled { get; init; }
}

public sealed record MfaStatusDto(
    bool Enabled,
    bool PendingSetup,
    DateTime? EnabledAt,
    int RecoveryCodesRemaining)
{
    /// <summary>
    /// Whether this user's role is expected to have a second factor. Purely advisory: the
    /// platform never blocks a sign-in on it, because a user who cannot reach an
    /// authenticator would be locked out of their own business with no way back in. Clients
    /// use it to push enrolment, not to gate access.
    /// </summary>
    public bool RequiredForThisUser { get; init; }
}

/// <summary>
/// Enrolment step one. <c>Secret</c> is returned in plain base32 because the user must be
/// able to type it into an authenticator app by hand; only its protected form is stored.
/// </summary>
public sealed record TwoFactorSetupDto(string Secret, string ProvisioningUri);

/// <summary>
/// The raw recovery codes, returned only when a batch is first generated. They
/// are not retrievable afterwards — only hashes are persisted — so the client
/// must show them and confirm the user has saved them before discarding this.
/// </summary>
public sealed record RecoveryCodesDto(IReadOnlyList<string> Codes)
{
    /// <summary>How many codes remain, so the client can warn before they run out.</summary>
    public int Remaining => Codes.Count;
}

/// <summary>
/// The response to a successful enrolment confirmation: the new status plus the first batch
/// of recovery codes. Bundled because only hashes are stored, so this response is the single
/// opportunity to show the user their codes.
/// </summary>
public sealed record TwoFactorEnabledDto(MfaStatusDto Status, RecoveryCodesDto RecoveryCodes);

/// <summary>
/// A device that currently holds a refresh token. Derived from the token's rotation family
/// rather than stored separately, so it can never disagree with the revocation state.
/// </summary>
public sealed record AuthSessionDto(
    Guid FamilyId,
    string Device,
    string? IpAddress,
    DateTime StartedAt,
    bool IsCurrent);

public sealed record AvailabilityResultDto(
    bool EmailAvailable,
    bool PhoneAvailable);
