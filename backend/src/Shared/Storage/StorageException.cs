namespace BusinessOS.Shared.Storage;

public class StorageException : Exception
{
    public StorageException(string message) : base(message)
    {
    }

    public StorageException(string message, Exception innerException) : base(message, innerException)
    {
    }
}

public sealed class StorageAlreadyExistsException : StorageException
{
    public StorageAlreadyExistsException(string key)
        : base($"Object '{key}' already exists in storage.")
    {
    }
}
