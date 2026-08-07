# Architecture

> Status: governing. Changes only via an approved ADR.

## System shape: Modular Monolith

One deployable host (`BusinessOS.Api`) containing the platform and all business modules as
vertical slices. Modules communicate through domain events, never direct calls. Workers
(background hosts) are the same modules in a separate process of the same deployment.

```
                ┌───────────────────────────────┐
                │        BusinessOS.Api          │  ONE deployment
                │      (modular monolith)        │
                │  ┌─────────── Platform ───────┐│
                │  │ Auth · Tenants · RBAC ·    ││
                │  │ Audit · Notifications ·    ││
                │  │ Search · Files · Settings  ││
                │  │ Workflow · Automation ·    ││
                │  │ Reporting · Sync · Plugins ││
                │  └────────────────────────────┘│
                │  ┌───── Modules ──────────────┐│
                │  │ CRM  Sales  Inventory      ││
                │  │ Acct  POS   Purchasing     ││
                │  └────────────────────────────┘│
                └───────────┬───────────────────┘
                            │ (outbox → reliable)
              ┌─────────────┴──────────────┐
              │ PostgreSQL · Redis · MinIO │
              └────────────────────────────┘
```

**Rule:** a module may reference platform contracts (`Application`) but never another module.

## Backend layers

```
API ──► Application (CQRS use cases) ──► Domain (entities, rules, events)
  │            │
  └──► Infrastructure (EF Core, Redis, JWT, outbox, event bus, seeding)
```

Dependency rule: each layer references only the one below it. `Infrastructure` is not
referenced by `Application` or `Domain` — implementations are injected at the composition
root (`API`).

## Domain-driven design

- Each module owns its models, rules, and events (aggregate roots, value objects, domain
  events). No cross-module entity sharing.
- `Domain` (platform) holds platform aggregates: Tenant, User, Role, Permission, AuditLog,
  FeatureFlag.
- `Shared` holds the kernel: `Entity`, `AggregateRoot`, `IDomainEvent`, `Result<T>`, `Error`.

## Event-driven by default

Modules raise domain events; interested modules/engines listen:

```
POS: SaleCompleted ──► Inventory (reduces stock)
                   ──► Accounting (posts journal entry)
                   ──► Notifications (SMS receipt)
                   ──► Analytics (aggregates)
                   ──► Audit (writes log)
```

Every event is persisted to an **outbox** table and delivered reliably by a worker — a
crashing consumer never loses an event. Consumers must be idempotent.

## CQRS

Reads and writes are separated. Writes go through commands (MediatR handlers) that change
state and raise events. Queries are thin and read-optimized. For MVP both share the same
database; the seam exists so read models/snapshots can diverge later.

## Multi-tenancy

- Shared database; `tenant_id` on every tenant-owned row.
- Repository guardrail: queries cannot run without a tenant filter (enforced in the query
  pipeline).
- Reference data that composes aggregates (e.g. the permission catalog feeding
  `Role.Grant`) is returned **tracked** by its repository so EF attaches it instead of
  re-inserting it.
- Schema-per-tenant is the documented escape hatch for enterprise, not the default.
- Feature flags gate module visibility per tenant.

## Offline-first sync

Device writes are stored in a Drift outbox (`SyncQueueItems`) and flushed over idempotent
REST endpoints. Server applies server-wins on `updatedAt` conflict (v1); per-table strategy
is configurable later.

## Key non-negotiables

1. Every mutation writes an audit log.
2. Every mutation happens inside a transaction that also persists domain events.
3. Every module ships with offline + RBAC + audit + events from day one or it doesn't ship.
4. No hardcoded business rules; tax/currency/units/sequences come from configuration.
5. API-first: REST before UI.
