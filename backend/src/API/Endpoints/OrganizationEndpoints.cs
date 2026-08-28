using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Branches.Commands;
using BusinessOS.Application.Features.Branches.Queries;
using BusinessOS.Application.Features.Organizations.Commands;
using BusinessOS.Application.Features.Organizations.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class OrganizationEndpoints
{
    public static IEndpointRouteBuilder MapOrganizationEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var organization = api.MapGroup("/organization")
            .WithApiVersionSet(versionSet)
            .WithTags("Organizations")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        organization.MapGet("/", GetOrganizationAsync)
            .RequirePermission(PermissionNames.OrganizationsView)
            .WithName("GetOrganization");
        organization.MapPut("/", UpdateOrganizationAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("UpdateOrganization");
        organization.MapPost("/onboarding", CompleteOnboardingAsync)
            .RequirePermission(PermissionNames.OrganizationsManage)
            .WithName("CompleteOnboarding");

        var workspaces = api.MapGroup("/workspaces")
            .WithApiVersionSet(versionSet)
            .RequireAuthorization()
            .RequireRateLimiting("global")
            .WithTags("Workspaces");
        workspaces.MapGet("/mine", GetMyWorkspacesAsync).WithName("GetMyWorkspaces");

        var branches = api.MapGroup("/branches")
            .WithApiVersionSet(versionSet)
            .WithTags("Branches")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        branches.MapGet("/", ListBranchesAsync)
            .RequirePermission(PermissionNames.BranchesView)
            .WithName("ListBranches");
        branches.MapPost("/", CreateBranchAsync)
            .RequirePermission(PermissionNames.BranchesCreate)
            .WithName("CreateBranch");
        branches.MapGet("/{id:guid}", GetBranchAsync)
            .RequirePermission(PermissionNames.BranchesView)
            .WithName("GetBranch");
        branches.MapPut("/{id:guid}", UpdateBranchAsync)
            .RequirePermission(PermissionNames.BranchesUpdate)
            .WithName("UpdateBranch");
        branches.MapPatch("/{id:guid}/status", SetBranchStatusAsync)
            .RequirePermission(PermissionNames.BranchesUpdate)
            .WithName("SetBranchStatus");

        return app;
    }

    private static async Task<IResult> GetOrganizationAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetOrganizationQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateOrganizationAsync(
        UpdateOrganizationCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> CompleteOnboardingAsync(
        CompleteOnboardingCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetMyWorkspacesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetMyWorkspacesQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListBranchesAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListBranchesQuery(page, pageSize), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateBranchAsync(
        CreateBranchCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetBranchAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetBranchQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateBranchAsync(
        Guid id,
        UpdateBranchCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> SetBranchStatusAsync(
        Guid id,
        SetBranchStatusRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetBranchStatusCommand(id, request.IsActive),
            cancellationToken)).ToApiResult();

    private sealed record SetBranchStatusRequest(bool IsActive);
}
