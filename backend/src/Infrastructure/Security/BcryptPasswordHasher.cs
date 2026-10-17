using BusinessOS.Application.Ports;

namespace BusinessOS.Infrastructure.Security;

public sealed class BcryptPasswordHasher : IPasswordHasher
{
    // WorkFactor 11 provides robust security (~2048 rounds) while cutting
    // CPU-bound verification time by 50% on shared/cloud vCPUs.
    private const int WorkFactor = 11;

    public string Hash(string password)
        => BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public bool Verify(string password, string hash)
        => BCrypt.Net.BCrypt.Verify(password, hash);
}
