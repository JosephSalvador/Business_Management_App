# API Standards

## Conventions

- **REST over HTTP/JSON.** Nouns = resources, plural (`/api/users`). Actions that are not
  CRUD are resources too (`/api/auth/login`).
- **Versioning:** URL prefix `/api/v1/` once a public contract exists. Internal (pre-1.0)
  endpoints may omit the version.
- **Base path:** `/api`. All routes registered as `app.MapGroup("/api")`.
- **Responses:** success returns the resource or `204`. Failure returns RFC 7807
  `ProblemDetails` with a stable `code` (`Validation`, `NotFound`, `Conflict`, `Unauthorized`).
- **Auth:** `Authorization: Bearer <jwt>`. All endpoints require auth except
  `/api/auth/login`, `/api/auth/register`, and health endpoints.
- **Idempotency:** mutating endpoints accept an `Idempotency-Key` header; the sync layer
  relies on this. Replays return the original result.
- **Pagination:** `?page=1&pageSize=50` → `{ items, page, pageSize, total }`.
- **Errors:** never leak stack traces or SQL to clients. Log details server-side.
- **OpenAPI:** `Microsoft.AspNetCore.OpenApi` serves `/openapi/v1.json`; Swagger UI in dev.
- **Audit:** every mutation is audited server-side (the endpoint does not need to call audit).

## Result contract

Handlers return `Result<T>` / `Result`. The API layer maps:

| Result | HTTP |
|---|---|
| Success | 200 / 201 / 204 |
| `Error.Validation` | 400 |
| `Error.Unauthorized` | 401 |
| `Error.NotFound` | 404 |
| `Error.Conflict` | 409 |
| `Error.Internal` | 500 |
