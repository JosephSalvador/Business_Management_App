using System.Text;
using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Security;

namespace BusinessOS.Tests.Unit.Identity;

/// <summary>
/// Covers the RFC 6238 mechanics against published test vectors plus the properties the
/// login flow depends on. <see cref="TotpService.VerifyCode"/> is called on every sign-in, so
/// a regression here locks every enrolled user out of their own business.
/// </summary>
public sealed class TotpServiceTests
{
    private readonly TotpService _totp = new();

    [Fact]
    public void VerifyCode_AcceptsRfc6238Sha1Vectors()
    {
        // RFC 6238 Appendix B uses the ASCII seed "12345678901234567890".
        var secret = TotpService.Base32Encode(Encoding.ASCII.GetBytes("12345678901234567890"));

        // T = 59s, 1111111109s, 1111111111s, 1234567890s, 2000000000s, 20000000000s.
        Assert.True(_totp.VerifyCode(secret, "94287082", At(59), 30, 8, 1));
        Assert.True(_totp.VerifyCode(secret, "07081804", At(1111111109), 30, 8, 1));
        Assert.True(_totp.VerifyCode(secret, "14050471", At(1111111111), 30, 8, 1));
        Assert.True(_totp.VerifyCode(secret, "89005924", At(1234567890), 30, 8, 1));
        Assert.True(_totp.VerifyCode(secret, "69279037", At(2000000000), 30, 8, 1));
        Assert.True(_totp.VerifyCode(secret, "65353130", At(20000000000), 30, 8, 1));
    }

    [Fact]
    public void VerifyCode_RejectsValueFromTheNextStepWhenWindowIsZero()
    {
        var secret = _totp.GenerateSecret();

        var stepTime = At(1_700_000_030);
        var code = TotpService.GenerateCode(
            TotpService.Base32Decode(secret),
            stepTime.ToUnixTimeSeconds() / 30 + 1,
            6);

        Assert.False(_totp.VerifyCode(secret, code, stepTime, 30, 6, 0));
    }

    [Fact]
    public void VerifyCode_ToleratesOneStepOfDriftEitherWay()
    {
        // Two separate secrets: replay suppression records the step a code matched, so reusing
        // one secret for both directions would make the second assertion fail for a reason
        // that has nothing to do with clock drift.
        var aheadSecret = _totp.GenerateSecret();
        var behindSecret = _totp.GenerateSecret();
        var now = At(1_700_000_030);
        var currentStep = now.ToUnixTimeSeconds() / 30;

        var ahead = TotpService.GenerateCode(TotpService.Base32Decode(aheadSecret), currentStep + 1, 6);
        var behind = TotpService.GenerateCode(TotpService.Base32Decode(behindSecret), currentStep - 1, 6);

        Assert.True(_totp.VerifyCode(aheadSecret, ahead, now, 30, 6, 1));
        Assert.True(_totp.VerifyCode(behindSecret, behind, now, 30, 6, 1));
    }

    [Fact]
    public void VerifyCode_AcceptsAMatchedCodeOnlyOnce()
    {
        // A TOTP code is valid across the whole window, so without replay tracking an
        // observed code could be reused for up to window*2+1 steps.
        var secret = _totp.GenerateSecret();
        var now = At(1_700_000_030);
        var code = TotpService.GenerateCode(TotpService.Base32Decode(secret), now.ToUnixTimeSeconds() / 30, 6);

        Assert.True(_totp.VerifyCode(secret, code, now, 30, 6, 1));
        Assert.False(_totp.VerifyCode(secret, code, now, 30, 6, 1));
    }

    [Theory]
    [InlineData("")]
    [InlineData("12345")]
    [InlineData("1234567")]
    [InlineData("12345a")]
    [InlineData("12 456")]
    public void VerifyCode_RejectsMalformedInput(string code)
    {
        var secret = _totp.GenerateSecret();
        Assert.False(_totp.VerifyCode(secret, code, At(1_700_000_030), 30, 6, 1));
    }

    [Fact]
    public void VerifyCode_RejectsAnUnusableSecretWithoutThrowing()
    {
        // A corrupt stored secret must fail the sign-in, not 500 the endpoint.
        Assert.False(_totp.VerifyCode("not-base32!!", "123456", At(1_700_000_030), 30, 6, 1));
        Assert.False(_totp.VerifyCode("", "123456", At(1_700_000_030), 30, 6, 1));
    }

    [Fact]
    public void Base32_RoundTrips()
    {
        for (var length = 1; length <= 32; length++)
        {
            var bytes = System.Security.Cryptography.RandomNumberGenerator.GetBytes(length);
            Assert.Equal(bytes, TotpService.Base32Decode(TotpService.Base32Encode(bytes)));
        }
    }

    [Fact]
    public void GeneratedSecret_IsBase32AndAcceptsPadding()
    {
        var secret = _totp.GenerateSecret();

        Assert.Equal(secret, secret.Trim().ToUpperInvariant());
        Assert.DoesNotContain('=', secret);
        // 20 bytes of entropy is the RFC 4226 recommendation for a shared secret.
        Assert.Equal(32, secret.Length);

        // Authenticator apps and users add padding; a secret typed back in must still work.
        var padded = secret + new string('=', (8 - secret.Length % 8) % 8);
        var code = TotpService.GenerateCode(
            TotpService.Base32Decode(padded), 1_700_000_030 / 30, 6);
        Assert.True(_totp.VerifyCode(padded, code, At(1_700_000_030), 30, 6, 1));
    }

    [Fact]
    public void ProvisioningUri_CarriesEverythingAScannerNeeds()
    {
        var secret = _totp.GenerateSecret();
        var uri = _totp.GetProvisioningUri(secret, "owner@shop.test", "Business OS");

        Assert.StartsWith("otpauth://totp/", uri);
        Assert.Contains("secret=$secret", uri);
        Assert.Contains("issuer=Business%20OS", uri);
        Assert.Contains("algorithm=SHA1", uri);
        Assert.Contains("digits=6", uri);
        Assert.Contains("period=30", uri);
    }

    [Fact]
    public void ProvisioningUri_EscapesASeparatorInTheAccountLabel()
    {
        // An unescaped colon would be read as the label/issuer separator and scan into the
        // wrong account.
        var uri = _totp.GetProvisioningUri(_totp.GenerateSecret(), "shop:owner", "Business OS");
        Assert.DoesNotContain("shop:owner", uri);
    }

    private static DateTimeOffset At(long unixSeconds) => DateTimeOffset.FromUnixTimeSeconds(unixSeconds);
}
