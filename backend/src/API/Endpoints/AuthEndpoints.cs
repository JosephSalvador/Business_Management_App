using Asp.Versioning.Builder;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Auth.Commands;
using BusinessOS.Application.Features.Auth.Queries;
using BusinessOS.Application.Features.Users.Commands;
using BusinessOS.Application.Features.Users.Queries;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var auth = api.MapGroup("/auth")
            .WithApiVersionSet(versionSet)
            .WithTags("Auth")
            .RequireRateLimiting("auth");

        auth.MapGet("/check-availability", CheckAvailabilityAsync).WithName("CheckAvailability");
        auth.MapPost("/register", RegisterAsync).WithName("Register");
        auth.MapPost("/register-staff", RegisterStaffAsync).WithName("RegisterStaff");
        auth.MapPost("/login", LoginAsync).WithName("Login");
        auth.MapPost("/refresh", RefreshAsync).WithName("Refresh");
        auth.MapPost("/revoke", RevokeAsync).WithName("Revoke");
        auth.MapPost("/verify-email", VerifyEmailAsync).WithName("VerifyEmail");
        auth.MapPost("/resend-verification", ResendVerificationAsync).WithName("ResendVerification");
        auth.MapPost("/forgot-password", ForgotPasswordAsync).WithName("ForgotPassword");
        auth.MapPost("/reset-password", ResetPasswordAsync).WithName("ResetPassword");

        // Pre-authorisation: the caller proved a password but not a second factor yet.
        // Rate limited with the rest of the auth surface, since it is the natural target
        // for a 6-digit brute force.
        auth.MapPost("/two-factor/verify", VerifyTwoFactorAsync).WithName("VerifyTwoFactor");

        // Own-account security management. These are intentionally permission-free: a role
        // misconfiguration must not be able to leave an owner unable to manage their own
        // second factor or their own devices. Access is gated on the authenticated
        // principal's own identity, which is what every handler below checks.
        var me = api.MapGroup("/me/security")
            .WithApiVersionSet(versionSet)
            .RequireAuthorization()
            .RequireRateLimiting("auth")
            .WithTags("Security");

        me.MapGet("/two-factor", GetMfaStatusAsync).WithName("GetMfaStatus");
        // Setup and regenerate take no input, so they are mapped with an explicit factory
        // rather than a command parameter: a parameterless command record would otherwise be
        // handed to body binding and fail on a request with no body.
        me.MapPost("/two-factor/setup", async (
                ISender sender,
                CancellationToken cancellationToken) =>
            (await sender.Send(new SetupTwoFactorCommand(), cancellationToken)).ToApiResult())
            .WithName("SetupTwoFactor");
        me.MapPost("/two-factor/confirm", ConfirmTwoFactorAsync).WithName("ConfirmTwoFactor");
        me.MapPost("/two-factor/disable", DisableTwoFactorAsync).WithName("DisableTwoFactor");
        me.MapPost("/two-factor/recovery-codes", async (
                ISender sender,
                CancellationToken cancellationToken) =>
            (await sender.Send(new RegenerateRecoveryCodesCommand(), cancellationToken)).ToApiResult())
            .WithName("RegenerateRecoveryCodes");
        me.MapGet("/sessions", ListMySessionsAsync).WithName("ListMySessions");
        me.MapDelete("/sessions/{sessionId:guid}", RevokeSessionAsync).WithName("RevokeSession");
        me.MapDelete("/sessions", RevokeAllSessionsAsync).WithName("RevokeAllSessions");

        var users = api.MapGroup("/users")
            .WithApiVersionSet(versionSet)
            .RequireAuthorization()
            .RequireRateLimiting("global")
            .WithTags("Users");
        users.MapGet("/me", GetCurrentUserAsync).WithName("GetCurrentUser");
        users.MapPut("/me", UpdateMyProfileAsync)
            .RequireRateLimiting("global")
            .WithName("UpdateMyProfile");
        users.MapPut("/me/password", ChangeMyPasswordAsync)
            .RequireRateLimiting("auth")
            .WithName("ChangeMyPassword");

        return app;
    }

    private static async Task<IResult> CheckAvailabilityAsync(
        string? email,
        string? phone,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CheckAvailabilityQuery(email, phone), cancellationToken)).ToApiResult();

    private static async Task<IResult> RegisterAsync(
        RegisterUserCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> RegisterStaffAsync(
        RegisterStaffCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> LoginAsync(
        LoginCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> RefreshAsync(
        RefreshTokenCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> RevokeAsync(
        RevokeSessionCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> VerifyEmailAsync(
        VerifyEmailCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> ResendVerificationAsync(
        ResendVerificationCodeCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> ForgotPasswordAsync(
        RequestPasswordResetCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> ResetPasswordAsync(
        ResetPasswordCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetCurrentUserAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetCurrentUserQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateMyProfileAsync(
        UpdateMyProfileCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> ChangeMyPasswordAsync(
        ChangeMyPasswordCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> VerifyTwoFactorAsync(
        VerifyTwoFactorCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetMfaStatusAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetMfaStatusQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> ConfirmTwoFactorAsync(
        ConfirmTwoFactorCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> DisableTwoFactorAsync(
        DisableTwoFactorCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> ListMySessionsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListMySessionsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> RevokeSessionAsync(
        Guid sessionId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new RevokeSessionByIdCommand(sessionId), cancellationToken)).ToApiResult();

    private static async Task<IResult> RevokeAllSessionsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new RevokeAllSessionsCommand(), cancellationToken)).ToApiResult();
}
