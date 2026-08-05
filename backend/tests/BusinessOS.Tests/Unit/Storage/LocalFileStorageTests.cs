using System.Text;
using BusinessOS.Infrastructure.Storage;
using BusinessOS.Shared.Configuration;
using BusinessOS.Shared.Storage;

namespace BusinessOS.Tests.Unit.Storage;

public sealed class LocalFileStorageTests : IDisposable
{
    private readonly string _rootPath = Path.Combine(Path.GetTempPath(), "bos-" + Guid.NewGuid());

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, recursive: true);
        }
    }

    private LocalFileStorage CreateStorage()
        => new(new StorageOptions { LocalRootPath = _rootPath });

    [Fact]
    public async Task PutAsync_WritesFile_ReturnsKey_AndExists()
    {
        var storage = CreateStorage();
        await using var content = new MemoryStream(Encoding.UTF8.GetBytes("hello world"));

        var key = await storage.PutAsync(content, "dir/sample.txt", "text/plain");

        Assert.Equal("dir/sample.txt", key);
        Assert.True(await storage.ExistsAsync(key));
        Assert.True(File.Exists(Path.Combine(_rootPath, "dir", "sample.txt")));
    }

    [Fact]
    public async Task GetAsync_ReturnsOriginalBytes()
    {
        var storage = CreateStorage();
        var expected = Encoding.UTF8.GetBytes("payload");
        await using var content = new MemoryStream(expected);
        await storage.PutAsync(content, "file.txt", "text/plain");

        await using var retrieved = await storage.GetAsync("file.txt");
        await using var actual = new MemoryStream();
        await retrieved.CopyToAsync(actual);

        Assert.Equal(expected, actual.ToArray());
    }

    [Fact]
    public async Task GetAsync_MissingKey_ThrowsFileNotFoundException()
    {
        var storage = CreateStorage();

        await Assert.ThrowsAsync<FileNotFoundException>(() => storage.GetAsync("missing.txt"));
    }

    [Fact]
    public async Task PutAsync_DuplicateKey_Throws()
    {
        var storage = CreateStorage();
        await using var first = new MemoryStream(Encoding.UTF8.GetBytes("first"));
        await storage.PutAsync(first, "dup.txt", "text/plain");
        await using var duplicate = new MemoryStream(Encoding.UTF8.GetBytes("second"));

        await Assert.ThrowsAsync<StorageAlreadyExistsException>(() => storage.PutAsync(duplicate, "dup.txt", "text/plain"));
    }

    [Fact]
    public async Task DeleteAsync_RemovesFile()
    {
        var storage = CreateStorage();
        await using var content = new MemoryStream(Encoding.UTF8.GetBytes("bye"));
        await storage.PutAsync(content, "bye.txt", "text/plain");
        Assert.True(await storage.ExistsAsync("bye.txt"));

        await storage.DeleteAsync("bye.txt");

        Assert.False(await storage.ExistsAsync("bye.txt"));
    }

    [Fact]
    public async Task PutAsync_PathTraversal_IsBlocked()
    {
        var storage = CreateStorage();
        var evilKey = $"../evil-{Guid.NewGuid():N}.txt";
        await using var content = new MemoryStream(Encoding.UTF8.GetBytes("evil"));

        await Assert.ThrowsAsync<InvalidOperationException>(() => storage.PutAsync(content, evilKey, "text/plain"));

        var outsidePath = Path.Combine(Path.GetTempPath(), evilKey);
        Assert.False(File.Exists(outsidePath));
    }

    [Fact]
    public void GetPublicUrl_UsesConfiguredBaseUrl()
    {
        var storage = new LocalFileStorage(new StorageOptions
        {
            LocalRootPath = _rootPath,
            PublicBaseUrl = "https://cdn.example.com/",
        });

        Assert.Equal("https://cdn.example.com/avatars/u1.png", storage.GetPublicUrl("avatars/u1.png"));
    }

    [Fact]
    public void GetPublicUrl_EmptyWhenNotConfigured()
    {
        var storage = CreateStorage();

        Assert.Equal(string.Empty, storage.GetPublicUrl("avatars/u1.png"));
    }
}
