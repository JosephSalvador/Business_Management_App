using Asp.Versioning.Builder;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Auth.Commands;
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

        auth.MapPost("/register", RegisterAsync).WithName("Register");
        auth.MapPost("/register-staff", RegisterStaffAsync).WithName("RegisterStaff");
        auth.MapPost("/login", LoginAsync).WithName("Login");
        auth.MapPost("/refresh", RefreshAsync).WithName("Refresh");
        auth.MapPost("/revoke", RevokeAsync).WithName("Revoke");
        auth.MapPost("/verify-email", VerifyEmailAsync).WithName("VerifyEmail");
        auth.MapPost("/resend-verification", ResendVerificationAsync).WithName("ResendVerification");
        auth.MapPost("/forgot-password", ForgotPasswordAsync).WithName("ForgotPassword");
        auth.MapPost("/reset-password", ResetPasswordAsync).WithName("ResetPassword");

        var users = api.MapGroup("/users")
            .WithApiVersionSet(versionSet)
            .RequireAuthorization()
            .RequireRateLimiting("global")
            .WithTags("Users");
        users.MapGet("/me", GetCurrentUserAsync).WithName("GetCurrentUser");

        return app;
    }

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
}
