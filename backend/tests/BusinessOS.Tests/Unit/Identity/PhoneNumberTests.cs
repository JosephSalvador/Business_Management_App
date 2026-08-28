using BusinessOS.Domain.Identity;
using Xunit;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class PhoneNumberTests
{
    [Theory]
    [InlineData("0712345678", "+255712345678")]
    [InlineData("0712 345 678", "+255712345678")]
    [InlineData("255712345678", "+255712345678")]
    [InlineData("+255712345678", "+255712345678")]
    [InlineData("00255712345678", "+255712345678")]
    [InlineData("+254712345678", "+254712345678")]
    [InlineData("+256712345678", "+256712345678")]
    public void Normalize_ReturnsCanonicalE164(string input, string expected)
    {
        Assert.Equal(expected, PhoneNumber.Normalize(input));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("12345")]
    [InlineData("07123456789")]
    [InlineData("not-a-phone")]
    public void Normalize_RejectsUnparseableInput(string? input)
    {
        Assert.Null(PhoneNumber.Normalize(input));
    }

    [Fact]
    public void IsNormalizable_MirrorsNormalize()
    {
        Assert.True(PhoneNumber.IsNormalizable("0712345678"));
        Assert.False(PhoneNumber.IsNormalizable("12345"));
    }
}
