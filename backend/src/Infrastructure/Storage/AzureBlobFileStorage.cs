using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using BusinessOS.Shared.Configuration;
using BusinessOS.Shared.Storage;

namespace BusinessOS.Infrastructure.Storage;

public sealed class AzureBlobFileStorage : IFileStorage
{
    private readonly BlobContainerClient _containerClient;
    private readonly string _publicBaseUrl;

    public AzureBlobFileStorage(StorageOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            throw new InvalidOperationException("Storage:ConnectionString must be configured for Azure Blob Storage.");
        }

        var containerName = string.IsNullOrWhiteSpace(options.ContainerName) ? "uploads" : options.ContainerName;
        _containerClient = new BlobContainerClient(options.ConnectionString, containerName);
        _containerClient.CreateIfNotExists(PublicAccessType.Blob);

        _publicBaseUrl = string.IsNullOrWhiteSpace(options.PublicBaseUrl)
            ? _containerClient.Uri.ToString().TrimEnd('/')
            : options.PublicBaseUrl.TrimEnd('/');
    }

    public async Task<string> PutAsync(Stream content, string key, string contentType, CancellationToken ct = default)
    {
        var blobClient = _containerClient.GetBlobClient(key);
        if (await blobClient.ExistsAsync(ct))
        {
            throw new StorageAlreadyExistsException(key);
        }

        var headers = new BlobHttpHeaders { ContentType = contentType };
        await blobClient.UploadAsync(content, new BlobUploadOptions { HttpHeaders = headers }, ct);
        return key;
    }

    public async Task<Stream> GetAsync(string key, CancellationToken ct = default)
    {
        var blobClient = _containerClient.GetBlobClient(key);
        try
        {
            var response = await blobClient.DownloadStreamingAsync(cancellationToken: ct);
            return response.Value.Content;
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            throw new FileNotFoundException($"Object '{key}' was not found in storage.", ex);
        }
    }

    public async Task<bool> ExistsAsync(string key, CancellationToken ct = default)
    {
        var blobClient = _containerClient.GetBlobClient(key);
        return await blobClient.ExistsAsync(ct);
    }

    public async Task DeleteAsync(string key, CancellationToken ct = default)
    {
        var blobClient = _containerClient.GetBlobClient(key);
        await blobClient.DeleteIfExistsAsync(cancellationToken: ct);
    }

    public string GetPublicUrl(string key)
        => $"{_publicBaseUrl}/{key.TrimStart('/')}";
}
