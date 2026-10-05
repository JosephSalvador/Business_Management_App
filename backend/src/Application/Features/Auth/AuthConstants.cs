namespace BusinessOS.Application.Features.Auth;

internal static class AuthConstants
{
    public const int AccessTokenMinutes = 15;
    public const int RefreshTokenDays = 30;

    /// <summary>Discriminator values for the <c>LoginResponse.Status</c> field.</summary>
    public const string LoginStatusAuthenticated = "authenticated";

    public const string LoginStatusTwoFactorRequired = "two_factor_required";
}
