namespace BusinessOS.Application.Features.Common;

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int Total);
