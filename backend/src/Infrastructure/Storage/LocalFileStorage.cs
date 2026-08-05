using BusinessOS.Shared.Configuration;
using BusinessOS.Shared.Storage;

namespace BusinessOS.Infrastructure.Storage;

public sealed class LocalFileStorage : IFileStorage
{
    private readonly string _rootPath;
    private readonly string _publicBaseUrl;

    public LocalFileStorage(StorageOptions options)
    {
        _rootPath = Path.GetFullPath(options.LocalRootPath);
        _publicBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        Directory.CreateDirectory(_rootPath);
    }

    public async Task<string> PutAsync(Stream content, string key, string contentType, CancellationToken ct = default)
    {
        var path = ResolvePath(key);
        if (File.Exists(path))
        {
            throw new StorageAlreadyExistsException(key);
        }

        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await using var fileStream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await content.CopyToAsync(fileStream, ct);
        return key;
    }

    public Task<Stream> GetAsync(string key, CancellationToken ct = default)
    {
        var path = ResolvePath(key);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException($"Object '{key}' was not found in storage.");
        }

        return Task.FromResult<Stream>(new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read));
    }

    public Task<bool> ExistsAsync(string key, CancellationToken ct = default)
        => Task.FromResult(File.Exists(ResolvePath(key)));

    public Task DeleteAsync(string key, CancellationToken ct = default)
    {
        var path = ResolvePath(key);
        if (File.Exists(path))
        {
            File.Delete(path);
        }

        return Task.CompletedTask;
    }

    public string GetPublicUrl(string key)
        => _publicBaseUrl.Length == 0 ? string.Empty : $"{_publicBaseUrl}/{key}";

    private string ResolvePath(string key)
    {
        var fullPath = Path.GetFullPath(Path.Combine(_rootPath, key));
        var rootPrefix = _rootPath.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (fullPath != _rootPath && !fullPath.StartsWith(rootPrefix, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Key '{key}' resolves outside the configured storage root.");
        }

        return fullPath;
    }
}
