using BusinessOS.Shared;
using Microsoft.AspNetCore.Mvc;

namespace BusinessOS.Api.Http;

public static class ResultExtensions
{
    public static IResult ToApiResult<T>(this Result<T> result)
        => result.IsSuccess ? Results.Ok(result.Value) : MapFailure(result.Error);

    public static IResult ToApiResult(this Result result)
        => result.IsSuccess ? Results.NoContent() : MapFailure(result.Error);

    private static IResult MapFailure(Error error)
    {
        var status = error.Code switch
        {
            "Validation" => StatusCodes.Status400BadRequest,
            "Unauthorized" => StatusCodes.Status401Unauthorized,
            "Forbidden" => StatusCodes.Status403Forbidden,
            "AccountNotVerified" => StatusCodes.Status403Forbidden,
            "NotFound" => StatusCodes.Status404NotFound,
            "Conflict" => StatusCodes.Status409Conflict,
            "TooManyRequests" => StatusCodes.Status429TooManyRequests,
            _ => StatusCodes.Status500InternalServerError,
        };

        ProblemDetails details;
        if (error.Code == "Validation" && error.Details is not null)
        {
            details = new ValidationProblemDetails(error.Details)
            {
                Title = "Validation Error",
                Detail = error.Message,
                Status = status,
            };
        }
        else
        {
            details = new ProblemDetails
            {
                Title = error.Code,
                Detail = error.Message,
                Status = status,
            };
        }

        details.Extensions["code"] = error.Code;

        return Results.Json(details, statusCode: status);
    }
}
