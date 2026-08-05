using BusinessOS.Infrastructure.Security;

namespace BusinessOS.Tests.Unit;

public sealed class PasswordHasherTests
{
    private readonly BcryptPasswordHasher _hasher = new();

    [Fact]
    public void Hash_ThenVerify_RoundTrips()
    {
        var hash = _hasher.Hash("Correct-Horse-42");
        Assert.NotEqual("Correct-Horse-42", hash);
        Assert.True(_hasher.Verify("Correct-Horse-42", hash));
    }

    [Fact]
    public void Verify_WrongPassword_Fails()
    {
        var hash = _hasher.Hash("Correct-Horse-42");
        Assert.False(_hasher.Verify("wrong", hash));
    }

    [Fact]
    public void Hash_IsSaltedPerCall()
    {
        var first = _hasher.Hash("same");
        var second = _hasher.Hash("same");
        Assert.NotEqual(first, second);
        Assert.True(_hasher.Verify("same", first));
        Assert.True(_hasher.Verify("same", second));
    }
}
