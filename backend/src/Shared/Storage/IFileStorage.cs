namespace BusinessOS.Shared.Storage;

public interface IFileStorage
{
    Task<string> PutAsync(Stream content, string key, string contentType, CancellationToken ct = default);

    Task<Stream> GetAsync(string key, CancellationToken ct = default);

    Task<bool> ExistsAsync(string key, CancellationToken ct = default);

    Task DeleteAsync(string key, CancellationToken ct = default);

    string GetPublicUrl(string key);
}
