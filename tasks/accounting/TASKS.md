# TASKS — Accounting (Slice 9)

> Spec: `specs/accounting.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: 9a Domain + Infrastructure → 9b Commands + Endpoints → 9c Event consumers
> → 9d Queries + Tests + docs. Commit style: `feat(accounting): ...`, `test(accounting): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## Architectural notes (from plan review)

- **No hardcoded accounts** — All event consumers resolve accounts via `TenantAccountMapping`.
- **Idempotency** — Every event consumer checks `(TenantId, ReferenceType, ReferenceId)`
  before creating a journal entry. Duplicate events are silently ignored.
- **Reversing entries** — Voiding a Posted entry creates a new mirroring JE (flipped
  debits/credits), not a mutation. Only Draft entries can be directly voided.
- **CurrentBalance** — `Account.CurrentBalance` is updated synchronously when a JE is
  posted. No SUM() queries over JournalEntryLines for balance lookups.

## 9a — Domain + Infrastructure

- [x] 001 **Permissions**: Add `AccountingCreate` to `PermissionNames`.
- [x] 002 **Domain — Account**: `AccountType` enum (`Asset | Liability | Equity | Revenue | Expense`), `Account` entity.
- [x] 003 **Domain — JournalEntry aggregate**: `JournalEntryStatus` enum, `JournalEntry` aggregate root.
- [x] 004 **Domain — JournalEntryLine**: `JournalEntryLine` entity.
- [x] 005 **Domain — TenantAccountMapping**: `TenantAccountMapping` entity + `AccountMappingKeys`.
- [x] 006 **Domain events**: `JournalEntryPostedEvent`, `JournalEntryVoidedEvent` records.
- [x] 007 **Infrastructure — migration**: `AddAccounting` migration.
- [x] 008 **Infrastructure — repositories**: EF implementations + DI.

## 9b — Commands + Endpoints

- [x] 009 **CreateAccount**: Command + handler + validator.
- [x] 010 **UpdateAccount**: Command + handler + validator.
- [x] 011 **CreateJournalEntry**: Command + handler + validator.
- [x] 012 **PostJournalEntry**: Command + handler.
- [x] 013 **VoidJournalEntry**: Command + handler.
- [x] 014 **IAccountMappingService**: Interface + implementation.
- [x] 015 **API — Accounts + Mappings endpoints**.
- [x] 016 **API — JournalEntry endpoints**.

## 9c — Event consumers

- [x] 017 **PostSaleJournalEntryHandler**: Idempotent, mapping-resolved.
- [x] 018 **PostSupplierBillJournalEntryHandler**: Idempotent, mapping-resolved.
- [x] 019 **PostSupplierPaymentJournalEntryHandler**: Idempotent, mapping-resolved.
- [x] 020 **AccountingActivityFeedHandler**: Registered in DI.
- [x] 021 **PostSaleVoidJournalEntryHandler**: Reversing entry handler.

## 9d — Queries + Tests + Docs

- [x] 022 **ListAccountsQuery**: Paginated, filterable.
- [x] 023 **TrialBalanceQuery**: Aggregates posted lines per account.
- [x] 024 **GeneralLedgerQuery**: Filtered by date range and account.
- [x] 025 **API — Report endpoints**: Trial balance + general ledger.
- [x] 026 **Tests + Docs**: 14 unit tests passing. Integration tests blocked on Postgres.
