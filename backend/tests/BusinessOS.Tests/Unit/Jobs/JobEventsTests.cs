using BusinessOS.Application.Jobs;

namespace BusinessOS.Tests.Unit.Jobs;

public sealed class JobEventsTests
{
    [Fact]
    public void SendEmailJob_Create_SetsIdOccurredAtAndTenant()
    {
        var tenantId = Guid.NewGuid();

        var job = SendEmailJob.Create(tenantId, "to@example.com", "Subject", "<p>Body</p>");

        Assert.NotEqual(Guid.Empty, job.EventId);
        Assert.True(DateTime.UtcNow - job.OccurredAt < TimeSpan.FromSeconds(5));
        Assert.Equal(tenantId, job.TenantId);
        Assert.Equal("to@example.com", job.To);
        Assert.Equal("Subject", job.Subject);
    }

    [Fact]
    public void SendSmsJob_Create_SetsIdOccurredAtAndTenant()
    {
        var tenantId = Guid.NewGuid();

        var job = SendSmsJob.Create(tenantId, "+255700000000", "Hello");

        Assert.NotEqual(Guid.Empty, job.EventId);
        Assert.True(DateTime.UtcNow - job.OccurredAt < TimeSpan.FromSeconds(5));
        Assert.Equal(tenantId, job.TenantId);
        Assert.Equal("+255700000000", job.PhoneNumber);
        Assert.Equal("Hello", job.Text);
    }

    [Fact]
    public void SendPushJob_Create_SetsIdOccurredAtAndTenant()
    {
        var tenantId = Guid.NewGuid();

        var job = SendPushJob.Create(tenantId, "device-1", "Title", "Body");

        Assert.NotEqual(Guid.Empty, job.EventId);
        Assert.True(DateTime.UtcNow - job.OccurredAt < TimeSpan.FromSeconds(5));
        Assert.Equal(tenantId, job.TenantId);
        Assert.Equal("device-1", job.DeviceToken);
        Assert.Equal("Title", job.Title);
    }

    [Fact]
    public void SendWhatsAppJob_Create_SetsIdOccurredAtAndTenant()
    {
        var tenantId = Guid.NewGuid();

        var job = SendWhatsAppJob.Create(tenantId, "+255711111111", "Karibu");

        Assert.NotEqual(Guid.Empty, job.EventId);
        Assert.True(DateTime.UtcNow - job.OccurredAt < TimeSpan.FromSeconds(5));
        Assert.Equal(tenantId, job.TenantId);
        Assert.Equal("+255711111111", job.PhoneNumber);
        Assert.Equal("Karibu", job.Text);
    }
}
