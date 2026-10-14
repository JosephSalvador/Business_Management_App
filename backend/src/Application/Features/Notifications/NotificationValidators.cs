using FluentValidation;

namespace BusinessOS.Application.Features.Notifications;

public sealed class RegisterDeviceRequestValidator : AbstractValidator<RegisterDeviceRequest>
{
    public RegisterDeviceRequestValidator()
    {
        RuleFor(x => x.DeviceId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.FcmToken).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(20);
        RuleFor(x => x.DeviceName).MaximumLength(100);
    }
}

public sealed class UpdateNotificationPreferencesRequestValidator : AbstractValidator<UpdateNotificationPreferencesRequest>
{
    public UpdateNotificationPreferencesRequestValidator()
    {
        RuleFor(x => x.HighSaleThreshold).GreaterThanOrEqualTo(0);
    }
}
