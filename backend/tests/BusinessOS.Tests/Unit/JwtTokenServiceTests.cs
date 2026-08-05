using System.IdentityModel.Tokens.Jwt;
using BusinessOS.Infrastructure.Security;

namespace BusinessOS.Tests.Unit;

public sealed class JwtTokenServiceTests
{
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();

    private static JwtTokenService CreateService()
        => new(new JwtOptions
        {
            Secret = "test-secret-test-secret-test-secret-test-secret!",
            Issuer = "businessos",
            Audience = "businessos-clients",
            AccessTokenMinutes = 15,
        });

    [Fact]
    public void GenerateAccessToken_EmbedsSubjectEmailTenantAndPermissions()
    {
        var service = CreateService();
        var token = service.GenerateAccessToken(UserId, TenantId, "dev@acme.local", new[] { "sales.read" });

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        Assert.Equal(UserId.ToString(), jwt.Subject);
        Assert.Equal(TenantId.ToString(), jwt.Claims.First(c => c.Type == "tenant_id").Value);
        Assert.Equal("dev@acme.local", jwt.Claims.First(c => c.Type == JwtRegisteredClaimNames.Email).Value);
        Assert.Equal("sales.read", jwt.Claims.First(c => c.Type == "permission").Value);
        Assert.Equal("businessos", jwt.Issuer);
        Assert.Contains("businessos-clients", jwt.Audiences);
    }

    [Fact]
    public void GenerateRefreshToken_IsUniquePerCall()
    {
        var service = CreateService();
        Assert.NotEqual(service.GenerateRefreshToken(), service.GenerateRefreshToken());
    }

    [Fact]
    public void HashRefreshToken_IsDeterministic()
    {
        var service = CreateService();
        var hash1 = service.HashRefreshToken("abc");
        var hash2 = service.HashRefreshToken("abc");
        Assert.Equal(hash1, hash2);
        Assert.NotEqual(hash1, service.HashRefreshToken("abd"));
    }
}
