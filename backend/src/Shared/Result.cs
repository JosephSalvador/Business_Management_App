namespace BusinessOS.Shared;

public readonly record struct Error(string Code, string Message)
{
    public IDictionary<string, string[]>? Details { get; init; }

    public static Error Validation(string message) => new("Validation", message);
    public static Error Validation(IDictionary<string, string[]> details)
        => new("Validation", "One or more validation errors occurred.") { Details = details };
    public static Error Conflict(string message) => new("Conflict", message);
    public static Error NotFound(string message) => new("NotFound", message);
    public static Error Unauthorized(string message) => new("Unauthorized", message);
    public static Error Forbidden(string message) => new("Forbidden", message);
    public static Error ModuleDisabled(string message) => new("ModuleDisabled", message);
    public static Error QuotaExceeded(string message) => new("QuotaExceeded", message);
    public static Error BillingRequired(string message) => new("BillingRequired", message);
    public static Error AccountNotVerified(string message) => new("AccountNotVerified", message);
    public static Error TooManyRequests(string message) => new("TooManyRequests", message);
    public static Error Internal(string message) => new("Internal", message);
}

public interface IResult<TResult> where TResult : IResult<TResult>
{
    static abstract TResult Failure(Error error);
}

public class Result : IResult<Result>
{
    protected Result(bool isSuccess, Error error)
    {
        IsSuccess = isSuccess;
        Error = error;
    }

    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;
    public Error Error { get; }

    public static Result Success() => new(true, default);
    public static Result Failure(Error error) => new(false, error);

    public static Result<T> Success<T>(T value) => Result<T>.Success(value);
    public static Result<T> Failure<T>(Error error) => Result<T>.Failure(error);
}

public class Result<T> : Result, IResult<Result<T>>
{
    private readonly T? _value;

    private Result(T value) : base(true, default) => _value = value;
    private Result(Error error) : base(false, error) => _value = default;

    public T Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException($"Cannot access value of a failed result: {Error.Message}");

    public static Result<T> Success(T value) => new(value);
    public static new Result<T> Failure(Error error) => new(error);

    public static implicit operator Result<T>(T value) => Success(value);
    public static implicit operator Result<T>(Error error) => Failure(error);
}
