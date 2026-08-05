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
        auth.MapPost("/login", LoginAsync).WithName("Login");
        auth.MapPost("/refresh", RefreshAsync).WithName("Refresh");
        auth.MapPost("/revoke", RevokeAsync).WithName("Revoke");

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

    private static async Task<IResult> GetCurrentUserAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetCurrentUserQuery(), cancellationToken)).ToApiResult();
}
