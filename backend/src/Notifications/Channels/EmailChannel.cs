using System.Net;
using System.Net.Mail;
using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using EmailMessage = BusinessOS.Application.Notifications.EmailMessage;

namespace BusinessOS.Notifications.Channels;

public sealed class EmailChannel
{
    private readonly SmtpOptions _options;
    private readonly ILogger<EmailChannel> _logger;

    public EmailChannel(IOptions<SmtpOptions> options, ILogger<EmailChannel> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public async Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.Host))
        {
            _logger.LogWarning("SMTP not configured");
            return;
        }

        var from = string.IsNullOrWhiteSpace(_options.From) ? message.From : _options.From;
        if (string.IsNullOrWhiteSpace(from))
        {
            throw new InvalidOperationException("SMTP From address is not configured.");
        }

        try
        {
            using var client = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.UseStartTls,
            };

            if (!string.IsNullOrWhiteSpace(_options.Username))
            {
                client.Credentials = new NetworkCredential(_options.Username, _options.Password);
            }

            // Bodies are plain Swahili text (verification / password-reset codes),
            // not HTML. Sending them as plain text keeps them readable in mail
            // clients (and MailHog) instead of base64-encoded HTML.
            using var mail = new MailMessage
            {
                From = new MailAddress(from),
                Subject = message.Subject,
                Body = message.HtmlBody,
                IsBodyHtml = false,
            };
            mail.To.Add(message.To);

            await client.SendMailAsync(mail, cancellationToken);
            _logger.LogInformation("Email sent to {To}", message.To);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {To}", message.To);
            throw;
        }
    }
}
