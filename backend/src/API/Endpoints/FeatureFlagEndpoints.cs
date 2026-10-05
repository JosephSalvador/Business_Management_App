using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Features.Commands;
using BusinessOS.Application.Features.Features.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class FeatureFlagEndpoints
{
    public static IEndpointRouteBuilder MapFeatureFlagEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var flags = api.MapGroup("/features")
            .WithApiVersionSet(versionSet)
            .WithTags("FeatureFlags")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        flags.MapGet("/", ListFeatureFlagsAsync)
            .RequirePermission(PermissionNames.OrganizationsView)
            .WithName("ListFeatureFlags");
        flags.MapGet("/{key}", GetFeatureFlagAsync)
            .RequirePermission(PermissionNames.OrganizationsView)
            .WithName("GetFeatureFlag");
        flags.MapPut("/{key}", SetFeatureFlagAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("SetFeatureFlag");

        return app;
    }

    private static async Task<IResult> ListFeatureFlagsAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListFeatureFlagsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetFeatureFlagAsync(
        string key, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetFeatureFlagQuery(key), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetFeatureFlagAsync(
        string key, SetFeatureFlagRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new SetFeatureFlagCommand(key, request.IsEnabled, request.Config), cancellationToken)).ToApiResult();

    private sealed record SetFeatureFlagRequest(bool IsEnabled, string? Config);
}
