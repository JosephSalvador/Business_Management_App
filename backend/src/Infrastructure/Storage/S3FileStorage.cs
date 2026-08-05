using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using BusinessOS.Shared.Configuration;
using BusinessOS.Shared.Storage;

namespace BusinessOS.Infrastructure.Storage;

public sealed class S3FileStorage : IFileStorage
{
    private readonly IAmazonS3 _client;
    private readonly string _bucket;
    private readonly string _publicBaseUrl;

    public S3FileStorage(StorageOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.Bucket))
        {
            throw new InvalidOperationException("Storage:Bucket must be configured for S3-compatible providers.");
        }

        _bucket = options.Bucket;
        _publicBaseUrl = options.PublicBaseUrl.TrimEnd('/');

        var config = new AmazonS3Config
        {
            ForcePathStyle = true,
            AuthenticationRegion = string.IsNullOrWhiteSpace(options.Region) ? "us-east-1" : options.Region,
        };
        if (!string.IsNullOrWhiteSpace(options.Endpoint))
        {
            config.ServiceURL = options.Endpoint;
        }

        var credentials = new BasicAWSCredentials(options.AccessKey, options.SecretKey);
        _client = new AmazonS3Client(credentials, config);
    }

    public async Task<string> PutAsync(Stream content, string key, string contentType, CancellationToken ct = default)
    {
        if (await ExistsAsync(key, ct))
        {
            throw new StorageAlreadyExistsException(key);
        }

        await _client.PutObjectAsync(new PutObjectRequest
        {
            BucketName = _bucket,
            Key = key,
            ContentType = contentType,
            InputStream = content,
        }, ct);

        return key;
    }

    public async Task<Stream> GetAsync(string key, CancellationToken ct = default)
    {
        try
        {
            var response = await _client.GetObjectAsync(_bucket, key, ct);
            return response.ResponseStream;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            throw new FileNotFoundException($"Object '{key}' was not found in storage.", ex);
        }
    }

    public async Task<bool> ExistsAsync(string key, CancellationToken ct = default)
    {
        try
        {
            await _client.GetObjectMetadataAsync(_bucket, key, ct);
            return true;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    public async Task DeleteAsync(string key, CancellationToken ct = default)
    {
        await _client.DeleteObjectAsync(_bucket, key, ct);
    }

    public string GetPublicUrl(string key)
        => _publicBaseUrl.Length == 0 ? string.Empty : $"{_publicBaseUrl}/{key}";
}
