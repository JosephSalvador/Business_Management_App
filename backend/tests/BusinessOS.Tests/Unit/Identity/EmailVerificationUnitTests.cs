using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Features.Organizations.Commands;
using BusinessOS.Application.Features.Auth.Commands;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using FluentValidation.TestHelper;
using Microsoft.Extensions.Options;
using BusinessOS.Shared.Configuration;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class EmailVerificationUnitTests
{
    private sealed class ThrowingOptions<T> : IOptions<T> where T : class, new()
    {
        public T Value => new();
    }

    [Theory]
    [InlineData("123456", true)]
    [InlineData("12345", false)]
    [InlineData("abcdef", false)]
    [InlineData("1234567", false)]
    [InlineData("", false)]
    public void VerifyEmailCommandValidator_CodeMustBeSixDigits(string code, bool valid)
    {
        var validator = new VerifyEmailCommandValidator();
        var result = validator.TestValidate(new VerifyEmailCommand("user@test.local", code));
        Assert.Equal(valid, result.IsValid);
    }

    [Fact]
    public void ResendVerificationCodeCommandValidator_RejectsInvalidEmail()
    {
        var validator = new ResendVerificationCodeCommandValidator();
        validator.TestValidate(new ResendVerificationCodeCommand("not-an-email")).ShouldHaveValidationErrorFor(x => x.Email);
        validator.TestValidate(new ResendVerificationCodeCommand("ok@test.local")).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void CompleteOnboardingCommandValidator_EnforcesIsoCodesAndKnownBusinessTypes()
    {
        var validator = new CompleteOnboardingCommandValidator();

        validator.TestValidate(new CompleteOnboardingCommand(
            "Duka", "retail", "TZ", "TZS", null, null)).ShouldNotHaveAnyValidationErrors();

        validator.TestValidate(new CompleteOnboardingCommand(
            "", "retail", "TZ", "TZS", null, null)).ShouldHaveValidationErrorFor(x => x.Name);

        validator.TestValidate(new CompleteOnboardingCommand(
            "Duka", "space-station", "TZ", "TZS", null, null)).ShouldHaveValidationErrorFor(x => x.BusinessType);

        validator.TestValidate(new CompleteOnboardingCommand(
            "Duka", "retail", "tza", "TZS", null, null)).ShouldHaveValidationErrorFor(x => x.CountryCode);

        validator.TestValidate(new CompleteOnboardingCommand(
            "Duka", "retail", "TZ", "TZSS", null, null)).ShouldHaveValidationErrorFor(x => x.Currency);
    }

    [Fact]
    public void Hash_IsStableSha256HexAndNeverEqualsTheRawCode()
    {
        var hash = EmailVerificationService.Hash("123456");
        Assert.Equal(EmailVerificationService.Hash("123456"), hash);
        Assert.NotEqual("123456", hash);
        Assert.Equal(64, hash.Length);
        Assert.All(hash.ToCharArray(), c => Assert.True(Uri.IsHexDigit(c)));
        Assert.Equal(EmailVerificationService.Hash(" 123456 "), hash); // trimmed
    }

    [Fact]
    public void VerificationCodeEntity_SingleUseAndAttemptLock()
    {
        var code = EmailVerificationCode.Create(Guid.NewGuid(), Guid.NewGuid(), "abc", DateTime.UtcNow.AddHours(1));
        Assert.True(code.IsUsable);

        for (var i = 1; i <= 4; i++)
        {
            code.RegisterFailedAttempt(5);
            Assert.True(code.IsUsable, $"attempt {i} must not lock yet");
        }

        code.RegisterFailedAttempt(5);
        Assert.False(code.IsUsable);
        Assert.False(code.TryConsume());
        Assert.NotNull(code.ConsumedAt);

        var fresh = EmailVerificationCode.Create(Guid.NewGuid(), Guid.NewGuid(), "def", DateTime.UtcNow.AddHours(1));
        Assert.True(fresh.TryConsume());
        Assert.False(fresh.TryConsume());
    }

    [Fact]
    public void User_MarkEmailVerified_RaisesEventOnce()
    {
        var user = User.Create(
            Guid.NewGuid(), Guid.NewGuid(), "u@test.local", "hash", "Uzer", null);
        Assert.False(user.EmailVerified);

        user.MarkEmailVerified();
        Assert.True(user.EmailVerified);
        Assert.Contains(user.DomainEvents, e => e.GetType().Name == "UserEmailVerifiedEvent");

        var eventCount = user.DomainEvents.Count(e => e.GetType().Name == "UserEmailVerifiedEvent");
        user.MarkEmailVerified();
        Assert.Equal(eventCount, user.DomainEvents.Count(e => e.GetType().Name == "UserEmailVerifiedEvent"));
    }

    [Fact]
    public void Tenant_CompleteOnboarding_StampsCompletionNormalizesCurrencyAndCountry()
    {
        var tenant = Tenant.Create(Guid.NewGuid(), "My Org");
        Assert.Null(tenant.OnboardingCompletedAt);

        tenant.CompleteOnboarding("Duka la Mama", "Retail ", "tz", " tzs ", "0712345678", "TIN-1");

        Assert.Equal("Duka la Mama", tenant.Name);
        Assert.Equal("Retail", tenant.BusinessType);
        Assert.Equal("TZ", tenant.CountryCode);
        Assert.Equal("TZS", tenant.Currency);
        Assert.NotNull(tenant.OnboardingCompletedAt);
    }

    [Fact]
    public void Tenant_CompleteOnboarding_RejectsBadCurrencyOrEmptyName()
    {
        var tenant = Tenant.Create(Guid.NewGuid(), "My Org");
        Assert.Throws<ArgumentException>(() =>
            tenant.CompleteOnboarding("", null, "TZ", "TZS", null, null));
        Assert.Throws<ArgumentException>(() =>
            tenant.CompleteOnboarding("Duka", null, "TZ", "TZSX!", null, null));
    }
}
