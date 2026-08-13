using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Roles.Commands;
using BusinessOS.Application.Features.Roles.Queries;
using BusinessOS.Application.Features.Users.Commands;
using BusinessOS.Application.Features.Users.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class IdentityEndpoints
{
    public static IEndpointRouteBuilder MapIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var users = api.MapGroup("/users")
            .WithApiVersionSet(versionSet)
            .WithTags("Users")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        users.MapGet("/", ListUsersAsync)
            .RequirePermission(PermissionNames.UsersView)
            .WithName("ListUsers");
        users.MapGet("/{id:guid}", GetUserAsync)
            .RequirePermission(PermissionNames.UsersView)
            .WithName("GetUser");
        users.MapPost("/", CreateUserAsync)
            .RequirePermission(PermissionNames.UsersCreate)
            .WithName("CreateUser");
        users.MapPut("/{id:guid}", UpdateUserAsync)
            .RequirePermission(PermissionNames.UsersUpdate)
            .WithName("UpdateUser");
        users.MapPut("/{id:guid}/roles", SetUserRolesAsync)
            .RequirePermission(PermissionNames.UsersUpdate)
            .WithName("SetUserRoles");
        users.MapGet("/{id:guid}/branches", GetUserBranchesAsync)
            .RequirePermission(PermissionNames.UsersView)
            .WithName("GetUserBranches");
        users.MapPut("/{id:guid}/branches", SetUserBranchesAsync)
            .RequirePermission(PermissionNames.UsersUpdate)
            .WithName("SetUserBranches");
        users.MapPatch("/{id:guid}/status", SetUserStatusAsync)
            .RequirePermission(PermissionNames.UsersUpdate)
            .WithName("SetUserStatus");
        users.MapDelete("/{id:guid}", DeleteUserAsync)
            .RequirePermission(PermissionNames.UsersDelete)
            .WithName("DeleteUser");

        var roles = api.MapGroup("/roles")
            .WithApiVersionSet(versionSet)
            .WithTags("Roles")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        roles.MapGet("/", ListRolesAsync)
            .RequirePermission(PermissionNames.RolesView)
            .WithName("ListRoles");
        roles.MapGet("/{id:guid}", GetRoleAsync)
            .RequirePermission(PermissionNames.RolesView)
            .WithName("GetRole");
        roles.MapPost("/", CreateRoleAsync)
            .RequirePermission(PermissionNames.RolesManage)
            .WithName("CreateRole");
        roles.MapPut("/{id:guid}", UpdateRoleAsync)
            .RequirePermission(PermissionNames.RolesManage)
            .WithName("UpdateRole");
        roles.MapDelete("/{id:guid}", DeleteRoleAsync)
            .RequirePermission(PermissionNames.RolesManage)
            .WithName("DeleteRole");
        roles.MapGet("/{id:guid}/permissions", GetRolePermissionsAsync)
            .RequirePermission(PermissionNames.RolesView)
            .WithName("GetRolePermissions");
        roles.MapPut("/{id:guid}/permissions", SetRolePermissionsAsync)
            .RequirePermission(PermissionNames.RolesManage)
            .WithName("SetRolePermissions");

        var permissions = api.MapGroup("/permissions")
            .WithApiVersionSet(versionSet)
            .WithTags("Permissions")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        permissions.MapGet("/", GetPermissionsAsync)
            .RequirePermission(PermissionNames.UsersView)
            .WithName("GetPermissions");

        return app;
    }

    private static async Task<IResult> ListUsersAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListUsersQuery(page, pageSize), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetUserAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetUserQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateUserAsync(
        CreateUserCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateUserAsync(
        Guid id,
        UpdateUserCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> SetUserRolesAsync(
        Guid id,
        SetUserRolesRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SetUserRolesCommand(id, request.RoleIds), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetUserBranchesAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetUserBranchesQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetUserBranchesAsync(
        Guid id,
        SetUserBranchesRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetUserBranchesCommand(id, request.BranchIds, request.DefaultBranchId),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> SetUserStatusAsync(
        Guid id,
        SetUserStatusRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SetUserStatusCommand(id, request.IsActive), cancellationToken)).ToApiResult();

    private static async Task<IResult> DeleteUserAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new DeleteUserCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListRolesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListRolesQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetRoleAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetRoleQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateRoleAsync(
        CreateRoleCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateRoleAsync(
        Guid id,
        UpdateRoleCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> DeleteRoleAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new DeleteRoleCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetRolePermissionsAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetRolePermissionsQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetRolePermissionsAsync(
        Guid id,
        SetRolePermissionsRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SetRolePermissionsCommand(id, request.PermissionNames), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetPermissionsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetPermissionsQuery(), cancellationToken)).ToApiResult();

    private sealed record SetUserRolesRequest(IReadOnlyList<Guid> RoleIds);
    private sealed record SetUserBranchesRequest(IReadOnlyList<Guid> BranchIds, Guid? DefaultBranchId);
    private sealed record SetUserStatusRequest(bool IsActive);
    private sealed record SetRolePermissionsRequest(IReadOnlyList<string> PermissionNames);
}
