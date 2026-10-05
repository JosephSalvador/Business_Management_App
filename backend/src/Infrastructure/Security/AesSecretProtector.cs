using System.Security.Cryptography;
using System.Text;
using BusinessOS.Application.Ports;
using BusinessOS.Shared.Configuration;

namespace BusinessOS.Infrastructure.Security;

/// <summary>
/// AES-GCM protection for second-factor shared secrets.
///
/// Keyed from <see cref="SecurityOptions.TwoFactorEncryptionKey"/> when configured, and
/// otherwise derived from the JWT secret, which the platform already validates at startup.
/// That fallback keeps deployment unchanged for existing installs while still giving a
/// distinct key per environment.
///
/// The consequence of relying on the fallback is worth stating plainly: rotating the JWT
/// secret also rotates this key, which invalidates **every** stored MFA secret, not just
/// staged ones. Each affected user then cannot produce a valid code and must re-enrol.
/// Deployments that rotate JWT secrets should therefore set
/// <c>Security:TwoFactorEncryptionKey</c> explicitly.
///
/// A fresh random key per process is deliberately *not* used: an operator restarting the API
/// must not silently break a second factor that is already live on a cashier's device.
/// </summary>
public sealed class AesSecretProtector : ISecretProtector
{
    private const int NonceSize = 12;
    private const int TagSize = 16;
    private const int KeySize = 32;

    private readonly byte[] _key;

    public AesSecretProtector(SecurityOptions options, JwtOptions jwt)
    {
        var material = string.IsNullOrWhiteSpace(options.TwoFactorEncryptionKey)
            ? jwt.Secret
            : options.TwoFactorEncryptionKey;

        if (string.IsNullOrWhiteSpace(material))
        {
            throw new InvalidOperationException(
                "A key is required to protect two-factor secrets. Configure Security:TwoFactorEncryptionKey.");
        }

        _key = SHA256.HashData(Encoding.UTF8.GetBytes(material));
    }

    public string Protect(string plaintext)
    {
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var plainBytes = Encoding.UTF8.GetBytes(plaintext);
        var cipher = new byte[plainBytes.Length];
        var tag = new byte[TagSize];

        using var aes = new AesGcm(_key, TagSize);
        aes.Encrypt(nonce, plainBytes, cipher, tag);

        return string.Join('.',
            Convert.ToBase64String(nonce),
            Convert.ToBase64String(tag),
            Convert.ToBase64String(cipher));
    }

    public string Unprotect(string protectedValue)
    {
        var parts = protectedValue.Split('.');
        if (parts.Length != 3)
        {
            throw new FormatException("The protected value is malformed.");
        }

        var nonce = Convert.FromBase64String(parts[0]);
        var tag = Convert.FromBase64String(parts[1]);
        var cipher = Convert.FromBase64String(parts[2]);

        if (nonce.Length != NonceSize || tag.Length != TagSize)
        {
            throw new FormatException("The protected value is malformed.");
        }

        var plain = new byte[cipher.Length];

        using var aes = new AesGcm(_key, TagSize);
        aes.Decrypt(nonce, cipher, tag, plain);

        return Encoding.UTF8.GetString(plain);
    }
}
