using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Tenants.Commands;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class TenantProvisioningEndpoints
{
    public static IEndpointRouteBuilder MapTenantProvisioningEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var admin = api.MapGroup("/admin/tenants")
            .WithApiVersionSet(versionSet)
            .WithTags("TenantProvisioning")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        admin.MapPost("/", ProvisionTenantAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("ProvisionTenant");
        admin.MapPost("/{tenantId:guid}/activate", ActivateTenantAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("ActivateTenant");
        admin.MapPost("/{tenantId:guid}/deactivate", DeactivateTenantAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("DeactivateTenant");

        return app;
    }

    private static async Task<IResult> ProvisionTenantAsync(
        ProvisionTenantRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new ProvisionTenantCommand(
                request.Name, request.Currency, request.CountryCode,
                request.BusinessType, request.ContactEmail, request.ContactPhone),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ActivateTenantAsync(
        Guid tenantId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ToggleTenantCommand(tenantId, true), cancellationToken)).ToApiResult();

    private static async Task<IResult> DeactivateTenantAsync(
        Guid tenantId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ToggleTenantCommand(tenantId, false), cancellationToken)).ToApiResult();

    private sealed record ProvisionTenantRequest(
        string Name, string? Currency, string? CountryCode,
        string? BusinessType, string? ContactEmail, string? ContactPhone);
}
