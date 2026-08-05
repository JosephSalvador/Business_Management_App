using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit;

public sealed class ResultTests
{
    [Fact]
    public void Success_ExposesValue()
    {
        var result = Result.Success("ok");
        Assert.True(result.IsSuccess);
        Assert.Equal("ok", result.Value);
    }

    [Fact]
    public void Failure_HidesValueAndExposesError()
    {
        var error = Error.Validation("bad input");
        Result<string> result = error;
        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Equal("bad input", result.Error.Message);
        Assert.Throws<InvalidOperationException>(() => result.Value);
    }

    [Fact]
    public void Value_ImplicitlyConvertsToSuccess()
    {
        Result<string> result = "hello";
        Assert.True(result.IsSuccess);
        Assert.Equal("hello", result.Value);
    }

    [Fact]
    public void StaticAbstractFactoryIsHonoredByConcreteType()
    {
        Result<string> failure = Result<string>.Failure(Error.NotFound("missing"));
        Assert.True(failure.IsFailure);
        Assert.Equal("NotFound", failure.Error.Code);
    }
}
