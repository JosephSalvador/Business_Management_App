# Feature Spec Template

> Copy this file for a new feature. OpenCode must not start coding until the spec is
> approved. `TASKS.md` (see `tasks/README.md`) breaks the spec into one-responsibility tasks.

## Feature

`<Name> — one-line description>`

## Purpose

Why this feature exists and who it serves.

## Business rules

- bullet list of authoritative rules (the "source of truth")

## Screens (Flutter)

- route, page, key interactions

## API (backend)

- endpoints, methods, request/response shapes, permissions required

## Database

- tables/columns/changes; migration notes; tenant/audit columns

## Validation

- field-level rules; error messages (EN/SW)

## Permissions

- permission names used; which roles get them (see `PermissionNames`)

## Events

- domain events raised/consumed (module decoupling)

## Reports

- any reports/aggregations affected

## Tests

- unit / integration / widget cases to add

## Offline & sync

- offline behavior, outbox entries, conflict strategy

## Future improvements

- deferred ideas (do NOT implement now)
