namespace BusinessOS.Application.Notifications;

public sealed record EmailMessage(string To, string Subject, string HtmlBody, string? From = null);

public sealed record SmsMessage(string PhoneNumber, string Text, string? SenderId = null);

public sealed record PushMessage(string DeviceToken, string Title, string Body, string? Data = null);

public sealed record WhatsAppMessage(string PhoneNumber, string Text);
