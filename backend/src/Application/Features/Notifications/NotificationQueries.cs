using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Notifications;

public sealed record GetNotificationsQuery(
    int Page = 1,
    int PageSize = 20,
    string? Category = null,
    bool? UnreadOnly = null)
    : IRequest<Result<PagedResult<NotificationDto>>>;

public sealed class GetNotificationsQueryHandler
    : IRequestHandler<GetNotificationsQuery, Result<PagedResult<NotificationDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAppNotificationRepository _notifications;

    public GetNotificationsQueryHandler(
        ITenantContext tenantContext,
        IAppNotificationRepository notifications)
    {
        _tenantContext = tenantContext;
        _notifications = notifications;
    }

    public async Task<Result<PagedResult<NotificationDto>>> Handle(
        GetNotificationsQuery request,
        CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;

        var filter = new NotificationListFilter(request.Category, request.UnreadOnly);
        var page = request.Page < 1 ? 1 : request.Page;
        var pageSize = request.PageSize switch
        {
            < 1 => 20,
            > 100 => 100,
            _ => request.PageSize
        };

        var items = await _notifications.ListPagedAsync(
            tenantId,
            userId,
            targetRole: null,
            page,
            pageSize,
            filter,
            cancellationToken);

        var dtos = items.Select(n => new NotificationDto(
            n.Id,
            n.UserId,
            n.TargetRole,
            n.BranchId,
            n.Category,
            n.Type,
            n.TitleSw,
            n.TitleEn,
            n.BodySw,
            n.BodyEn,
            n.DataJson,
            n.IsRead,
            n.ReadAt,
            n.CreatedAt)).ToList();

        var total = await _notifications.GetUnreadCountAsync(
            tenantId,
            userId,
            targetRole: null,
            cancellationToken);

        return Result.Success(new PagedResult<NotificationDto>(
            dtos,
            page,
            pageSize,
            total));
    }
}

public sealed record GetUnreadNotificationCountQuery() : IRequest<Result<UnreadCountDto>>;

public sealed class GetUnreadNotificationCountQueryHandler
    : IRequestHandler<GetUnreadNotificationCountQuery, Result<UnreadCountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAppNotificationRepository _notifications;

    public GetUnreadNotificationCountQueryHandler(
        ITenantContext tenantContext,
        IAppNotificationRepository notifications)
    {
        _tenantContext = tenantContext;
        _notifications = notifications;
    }

    public async Task<Result<UnreadCountDto>> Handle(
        GetUnreadNotificationCountQuery request,
        CancellationToken cancellationToken)
    {
        var count = await _notifications.GetUnreadCountAsync(
            _tenantContext.TenantId,
            _tenantContext.UserId,
            targetRole: null,
            cancellationToken);

        return Result.Success(new UnreadCountDto(count));
    }
}

public sealed record GetNotificationPreferencesQuery() : IRequest<Result<NotificationPreferencesDto>>;

public sealed class GetNotificationPreferencesQueryHandler
    : IRequestHandler<GetNotificationPreferencesQuery, Result<NotificationPreferencesDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly INotificationPreferenceRepository _preferences;

    public GetNotificationPreferencesQueryHandler(
        ITenantContext tenantContext,
        INotificationPreferenceRepository preferences)
    {
        _tenantContext = tenantContext;
        _preferences = preferences;
    }

    public async Task<Result<NotificationPreferencesDto>> Handle(
        GetNotificationPreferencesQuery request,
        CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;

        var pref = await _preferences.GetByTenantAndUserAsync(tenantId, userId, cancellationToken)
            ?? await _preferences.GetByTenantAndUserAsync(tenantId, null, cancellationToken);

        if (pref is null)
        {
            return Result.Success(new NotificationPreferencesDto(
                NotifyCashShortage: true,
                NotifySaleVoided: true,
                NotifyLowStock: true,
                HighSaleThreshold: 500000m,
                PushEnabled: true));
        }

        return Result.Success(new NotificationPreferencesDto(
            pref.NotifyCashShortage,
            pref.NotifySaleVoided,
            pref.NotifyLowStock,
            pref.HighSaleThreshold,
            pref.PushEnabled));
    }
}
