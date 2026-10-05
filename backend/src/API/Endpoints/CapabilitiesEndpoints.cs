using Asp.Versioning.Builder;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Billing.Queries;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class CapabilitiesEndpoints
{
    public static IEndpointRouteBuilder MapCapabilitiesEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        api.MapGet("/capabilities", GetCapabilitiesAsync)
            .WithApiVersionSet(versionSet)
            .WithTags("Capabilities")
            .RequireAuthorization()
            .RequireRateLimiting("global")
            .WithName("GetCapabilities");

        return app;
    }

    private static async Task<IResult> GetCapabilitiesAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetCapabilitiesQuery(), cancellationToken)).ToApiResult();
}
