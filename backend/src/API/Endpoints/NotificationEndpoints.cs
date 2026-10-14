using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Notifications;
using BusinessOS.Domain.Identity;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BusinessOS.Api.Endpoints;

public static class NotificationEndpoints
{
    public static IEndpointRouteBuilder MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var notifications = api.MapGroup("/notifications")
            .WithApiVersionSet(versionSet)
            .WithTags("Notifications")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        notifications.MapGet("/", ListNotificationsAsync)
            .RequirePermission(PermissionNames.NotificationsView)
            .WithName("ListNotifications");

        notifications.MapGet("/unread-count", GetUnreadCountAsync)
            .RequirePermission(PermissionNames.NotificationsView)
            .WithName("GetUnreadNotificationCount");

        notifications.MapPatch("/{id:guid}/read", MarkReadAsync)
            .RequirePermission(PermissionNames.NotificationsView)
            .WithName("MarkNotificationRead");

        notifications.MapPost("/mark-all-read", MarkAllReadAsync)
            .RequirePermission(PermissionNames.NotificationsView)
            .WithName("MarkAllNotificationsRead");

        notifications.MapGet("/preferences", GetPreferencesAsync)
            .RequirePermission(PermissionNames.NotificationsView)
            .WithName("GetNotificationPreferences");

        notifications.MapPut("/preferences", UpdatePreferencesAsync)
            .RequirePermission(PermissionNames.NotificationsManage)
            .WithName("UpdateNotificationPreferences");

        var devices = api.MapGroup("/devices")
            .WithApiVersionSet(versionSet)
            .WithTags("Devices")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        devices.MapPost("/register", RegisterDeviceAsync)
            .WithName("RegisterDevice");

        devices.MapDelete("/{deviceId}", UnregisterDeviceAsync)
            .WithName("UnregisterDevice");

        return app;
    }

    private static async Task<IResult> ListNotificationsAsync(
        int? page,
        int? pageSize,
        string? category,
        bool? unreadOnly,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new GetNotificationsQuery(page ?? 1, pageSize ?? 20, category, unreadOnly),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetUnreadCountAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetUnreadNotificationCountQuery(), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> MarkReadAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new MarkNotificationReadCommand(id), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> MarkAllReadAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new MarkAllNotificationsReadCommand(), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> GetPreferencesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetNotificationPreferencesQuery(), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> UpdatePreferencesAsync(
        [FromBody] UpdateNotificationPreferencesRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateNotificationPreferencesCommand(
                request.NotifyCashShortage,
                request.NotifySaleVoided,
                request.NotifyLowStock,
                request.HighSaleThreshold,
                request.PushEnabled),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RegisterDeviceAsync(
        [FromBody] RegisterDeviceRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new RegisterUserDeviceCommand(
                request.DeviceId,
                request.FcmToken,
                request.Platform,
                request.DeviceName),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> UnregisterDeviceAsync(
        string deviceId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new UnregisterUserDeviceCommand(deviceId), cancellationToken))
            .ToApiResult();
}
