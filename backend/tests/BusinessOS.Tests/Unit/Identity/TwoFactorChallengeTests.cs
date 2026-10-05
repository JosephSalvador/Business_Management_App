using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Domain.Identity;

namespace BusinessOS.Tests.Unit.Identity;

/// <summary>
/// The challenge is the only thing standing between a correct password and a session, so its
/// rules are asserted directly rather than only through the login endpoint.
/// </summary>
public sealed class TwoFactorChallengeTests
{
    [Fact]
    public void ANewChallenge_IsUsable()
    {
        var challenge = TwoFactorChallenge.Create(Guid.NewGuid(), Guid.NewGuid(), "hash", DateTime.UtcNow.AddMinutes(5));

        Assert.True(challenge.IsUsable);
    }

    [Fact]
    public void TryConsume_SucceedsExactlyOnce()
    {
        var challenge = TwoFactorChallenge.Create(Guid.NewGuid(), Guid.NewGuid(), "hash", DateTime.UtcNow.AddMinutes(5));

        Assert.True(challenge.TryConsume());
        Assert.False(challenge.TryConsume());
        Assert.False(challenge.IsUsable);
    }

    [Fact]
    public void AnExpiredChallenge_IsNotUsableAndCannotBeConsumed()
    {
        var challenge = TwoFactorChallenge.Create(Guid.NewGuid(), Guid.NewGuid(), "hash", DateTime.UtcNow.AddMinutes(-1));

        Assert.False(challenge.IsUsable);
        Assert.False(challenge.TryConsume());
    }

    [Fact]
    public void RegisterFailedAttempt_LocksTheChallengeAtTheLimit()
    {
        var challenge = TwoFactorChallenge.Create(Guid.NewGuid(), Guid.NewGuid(), "hash", DateTime.UtcNow.AddMinutes(5));

        challenge.RegisterFailedAttempt(3);
        Assert.True(challenge.IsUsable);

        challenge.RegisterFailedAttempt(3);
        Assert.True(challenge.IsUsable);

        // Third wrong code spends the challenge, so a stolen token cannot be used to
        // iterate all million TOTP values inside its lifetime.
        challenge.RegisterFailedAttempt(3);
        Assert.False(challenge.IsUsable);
        Assert.False(challenge.TryConsume());
    }

    [Fact]
    public void ConsumingOneChallenge_DoesNotAffectAnotherForTheSameUser()
    {
        var userId = Guid.NewGuid();
        var tenantId = Guid.NewGuid();
        var first = TwoFactorChallenge.Create(tenantId, userId, "hash-1", DateTime.UtcNow.AddMinutes(5));
        var second = TwoFactorChallenge.Create(tenantId, userId, "hash-2", DateTime.UtcNow.AddMinutes(5));

        Assert.True(first.TryConsume());

        Assert.True(second.IsUsable);
    }

    [Fact]
    public void RecoveryCode_CanBeConsumedOnlyOnce()
    {
        var code = TwoFactorRecoveryCode.Create(Guid.NewGuid(), Guid.NewGuid(), "hash");

        Assert.False(code.IsUsed);
        Assert.True(code.TryConsume());
        Assert.True(code.IsUsed);
        Assert.NotNull(code.UsedAt);
        Assert.False(code.TryConsume());
    }
}

/// <summary>
/// Enrolment must never activate a secret the user could not prove they hold.
/// </summary>
public sealed class TwoFactorEnrolmentTests
{
    private static User CreateUser()
        => User.Create(Guid.NewGuid(), Guid.NewGuid(), "owner@shop.test", "hash", "Owner", null);

    [Fact]
    public void StagedSecret_DoesNotEnableTheFactor()
    {
        var user = CreateUser();

        user.StageTwoFactor("protected-secret");

        Assert.True(user.HasPendingTwoFactor);
        Assert.False(user.TwoFactorEnabled);
        Assert.Null(user.TwoFactorSecret);
    }

    [Fact]
    public void Confirm_PromotesTheStagedSecret()
    {
        var user = CreateUser();
        user.StageTwoFactor("protected-secret");

        Assert.True(user.ConfirmTwoFactor());

        Assert.True(user.TwoFactorEnabled);
        Assert.Equal("protected-secret", user.TwoFactorSecret);
        Assert.Null(user.TwoFactorPendingSecret);
        Assert.NotNull(user.TwoFactorEnabledAt);
    }

    [Fact]
    public void Confirm_WithoutAStagedSecret_Fails()
    {
        var user = CreateUser();

        Assert.False(user.ConfirmTwoFactor());
        Assert.False(user.TwoFactorEnabled);
    }

    [Fact]
    public void Confirm_CannotBeReplayedToEnableASecondTime()
    {
        var user = CreateUser();
        user.StageTwoFactor("first");
        Assert.True(user.ConfirmTwoFactor());

        // A duplicated confirm request must not silently re-promote or wipe the secret.
        Assert.False(user.ConfirmTwoFactor());
        Assert.Equal("first", user.TwoFactorSecret);
    }

    [Fact]
    public void Disable_ClearsBothSecrets()
    {
        var user = CreateUser();
        user.StageTwoFactor("secret");
        user.ConfirmTwoFactor();

        user.DisableTwoFactor();

        Assert.False(user.TwoFactorEnabled);
        Assert.Null(user.TwoFactorSecret);
        Assert.Null(user.TwoFactorPendingSecret);
        Assert.Null(user.TwoFactorEnabledAt);
    }

    [Fact]
    public void RestagingWhileEnabled_KeepsTheActiveFactorIntact()
    {
        // Re-enrolling must not break the factor currently in the user's authenticator:
        // the old one stays valid until the new one is confirmed.
        var user = CreateUser();
        user.StageTwoFactor("active");
        user.ConfirmTwoFactor();
        var enabledAt = user.TwoFactorEnabledAt;

        user.StageTwoFactor("replacement");

        Assert.True(user.TwoFactorEnabled);
        Assert.Equal("active", user.TwoFactorSecret);
        Assert.Equal("replacement", user.TwoFactorPendingSecret);
        Assert.Equal(enabledAt, user.TwoFactorEnabledAt);
    }
}

/// <summary>
/// Recovery codes are only ever stored hashed, and are normalised so a user transcribing one
/// from a printout is not defeated by their own formatting.
/// </summary>
public sealed class RecoveryCodeHashingTests
{
    [Fact]
    public void Hash_IsStableAndCaseInsensitive()
    {
        var a = TwoFactorSecretService.HashRecoveryCode("ABCD2345EF");
        var b = TwoFactorSecretService.HashRecoveryCode("  abcd-2345-ef ");

        Assert.Equal(a, b);
    }

    [Fact]
    public void Hash_DoesNotEqualTheRawCode()
    {
        const string raw = "ABCD2345EF";

        Assert.NotEqual(raw, TwoFactorSecretService.HashRecoveryCode(raw));
    }

    [Theory]
    [InlineData("ABCD2345EF", true)]
    [InlineData("abcd2345ef", true)]
    [InlineData("ABCD-2345-EF", true)]
    [InlineData("SHORT", false)]
    [InlineData("TOOLONGCODE12", false)]
    [InlineData("HAS SPACE!!", false)]
    public void WellFormed_AcceptsTranscribableCodesOnly(string code, bool expected)
        => Assert.Equal(expected, TwoFactorSecretService.IsWellFormedRecoveryCode(code));
}
