# Coding Standards

> Applies to backend (C#) and frontend (Dart). Follow the surrounding code when in doubt.

## C# (backend)

- **Namespaces:** `BusinessOS.<Layer>.<Module>.<Topic>` e.g. `BusinessOS.Domain.Identity`.
- **Folders:** match namespaces. Platform concerns live under the layer folder; modules under
  `Modules/<Name>`.
- **Files:** one primary type per file, filename = type name.
- **Naming:** `PascalCase` types/methods/properties, `_camelCase` private fields,
  `PascalCase` constants, `ISomething` interfaces.
- **Immutability:** entities use private setters + factory methods (`Create`, `Seed`);
  records for events, DTOs, and value objects.
- **Errors:** return `Result<T>` / `Error`; never throw for expected failures. Throw only
  for programmer errors. Map to `ProblemDetails` at the API boundary.
- **Async:** async/await end-to-end; no sync-over-async (`.Result`, `.Wait()`).
- **Logging:** Serilog structured logs (`Log.Information("User {UserId} logged in", id)`),
  never string concatenation. `Microsoft.Extensions.Logging` via `ILogger<T>` in handlers.
- **Validation:** FluentValidation in Application commands; data annotations only for
  transport DTOs.
- **Nullability:** `nullable` enabled; `String.Empty` over `""`; avoid `null!` unless mapped EF.
- **EF:** repositories in Infrastructure; context maps configured in one place per aggregate.
  Every mapping declares `ToTable(name, schema)` using the `Tables`/`Schemas` catalog in
  `Infrastructure/Persistence/TableNames.cs` — never raw table-name strings or provider defaults.

## Dart (Flutter)

- **Naming:** `lowerCamelCase` for functions/vars, `PascalCase` classes, `SCREAMING_SNAKE` consts.
- **Imports:** `package:` absolute; group dart → package → relative; `flutter analyze` clean.
- **State:** Riverpod providers in feature folders; UI reads providers, never business logic.
- **Routing:** go_router; routes gated by permission helper.
- **Formatting:** `dart format`; run `flutter analyze` before committing.

## Both

- No comments that restate the code. Comments explain *why*, not *what*.
- No dead code, no commented-out code.
- No secrets in code or committed config. Dev-only values are allowed in
  `appsettings.Development.json` / `*.dart` dev config explicitly marked dev-only.
- Tests: unit tests for rules, integration tests for repository + API flows.
