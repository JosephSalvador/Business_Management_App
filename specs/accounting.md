# Feature Spec — Accounting (Slice 9)

> Status: `[ ]` spec draft · awaiting approval before implementation.

## Feature

Double-entry bookkeeping engine: Chart of Accounts, Journal Entries, General Ledger,
Trial Balance. Consumes events from Sales and Purchasing to auto-post journal entries.
Multi-tenant with per-tenant configurable account mappings.

## Purpose

Accounting is the financial backbone that connects operational modules (Sales, Purchasing)
to financial reporting. Every monetary event in the system produces a balanced journal entry:

```
Sale Completed     → Debit Cash, Credit Revenue + VAT Payable
Supplier Bill      → Debit Expense, Credit Accounts Payable
Supplier Payment   → Debit Accounts Payable, Credit Cash
Sale Voided        → Reversing entry (flip debits/credits of original)
```

- Enables Trial Balance, General Ledger, and per-account balance queries.
- Account mappings are per-tenant (not hardcoded) — tenants configure which accounts
  map to which business functions (Sales Revenue, Cash, AP, etc.).
- Event consumers are idempotent (at-least-once outbox delivery is safe).
- Posted entries are immutable; voiding creates a reversing entry.

## Sub-slices

| Slice | Scope |
|-------|-------|
| 9a | Domain (Account, JournalEntry, JournalEntryLine, TenantAccountMapping) + Migration + Repositories |
| 9b | Commands (CreateAccount, UpdateAccount, CreateJournalEntry, PostJournalEntry, VoidJournalEntry) + Endpoints |
| 9c | Event consumers (Sale → JE, SupplierBill → JE, SupplierPayment → JE, SaleVoided → Reversing JE) |
| 9d | Queries (TrialBalance, GeneralLedger) + Tests + Docs |

## Business rules

### Account (Chart of Accounts)

1. `AccountType` enum: `Asset`, `Liability`, `Equity`, `Revenue`, `Expense`.
2. `AccountNormalBalance` derived from type: Assets/Expenses = Debit normal;
   Liabilities/Equity/Revenue = Credit normal.
3. `Account` entity fields: Id, TenantId, Code (required, unique per tenant),
   Name (required ≤200), AccountType, ParentAccountId (nullable, for sub-accounts),
   CurrentBalance (decimal, updated synchronously on post), IsActive, Notes.
4. `CurrentBalance` is maintained incrementally: when a JE is posted, each line
   adjusts the account's balance. This avoids SUM() over millions of rows.
5. Account hierarchy: parent/child for sub-accounts (e.g., "1110 Petty Cash" under
   "1100 Cash and Bank"). Parent account balance = sum of children (computed at
   query time, not stored).
6. Cannot delete an account that has journal entry lines (soft-deactivate instead).
7. Cannot change Code or AccountType after creation.

### TenantAccountMapping (per-tenant account configuration)

1. Maps business function keys (e.g., "SalesRevenue", "CashAndBank", "AccountsPayable",
   "VATPayable", "InventoryAsset") to AccountIds.
2. One mapping row per key per tenant. Created during tenant onboarding or first use.
3. Event consumers MUST resolve accounts via this mapping — never hardcode account codes.
4. If a mapping is missing, the event consumer returns an error (does not guess).

Keys (constants):
- `SalesRevenue` — credit on sale
- `CashAndBank` — debit on sale, credit on supplier payment
- `AccountsPayable` — credit on supplier bill, debit on supplier payment
- `VATPayable` — credit on sale (tax portion)
- `InventoryAsset` — debit on supplier bill (goods received)
- `CostOfGoodsSold` — debit on sale (cost portion, future)

### Journal Entry

1. `JournalEntryStatus` enum: `Draft`, `Posted`, `Void`.
2. Fields: Id, TenantId, Reference (optional string), ReferenceType (optional string),
   ReferenceId (nullable Guid), EntryDate, Description, Status, PostedAt, VoidedAt,
   Lines (IReadOnlyList<JournalEntryLine>).
3. Creating a JE: at least 2 lines, DebitTotal == CreditTotal (balanced).
4. Status transitions:
   - `Draft → Posted` (sets PostedAt, updates Account.CurrentBalance for each line)
   - `Draft → Void` (sets VoidedAt, does NOT affect balances — it was never posted)
   - `Posted → Void` is NOT allowed directly; instead create a Reversing Entry
5. Every Posted entry raises `JournalEntryPostedEvent`.
6. Every Voided entry raises `JournalEntryVoidedEvent`.

### JournalEntryLine

1. Fields: Id, JournalEntryId, AccountId, DebitAmount (≥0), CreditAmount (≥0),
   Description (optional).
2. Exactly one of Debit or Credit must be > 0 (not both, not neither).
3. Amount must be > 0.

### Reversing Entries (for voiding Posted entries)

1. When a `SaleVoidedEvent` is received, the system creates a NEW JournalEntry
   (Status: Posted) that is the mirror image of the original:
   - Same ReferenceType/ReferenceId as the original
   - All DebitAmounts become CreditAmounts and vice versa
   - EntryDate = current time
   - Description = "Reversal of {original description}"
2. The reversing entry's lines update Account.CurrentBalance (credit accounts get
   debited, debit accounts get credited).
3. The original entry remains untouched (immutable). Its `VoidedAt` is NOT set —
   only manually-created Draft entries can be voided directly.

### Idempotency

1. All event consumers (Tasks 017–019, 021) MUST check for an existing journal entry
   with the same (TenantId, ReferenceType, ReferenceId) before creating a new one.
2. If an entry already exists, the handler returns success without creating a duplicate.
3. This prevents double-posting from at-least-once outbox delivery.

### Balance Updates

1. When a JournalEntry transitions to `Posted`, for each line:
   - If DebitAmount > 0: Account.CurrentBalance += DebitAmount (for Debit-normal accounts)
     or Account.CurrentBalance -= DebitAmount (for Credit-normal accounts)
   - If CreditAmount > 0: Account.CurrentBalance += CreditAmount (for Credit-normal accounts)
     or Account.CurrentBalance -= CreditAmount (for Debit-normal accounts)
2. The sign convention: CurrentBalance stores the absolute balance in the account's
   normal direction. For Debit-normal accounts (Assets, Expenses): balance = total debits
   minus total credits. For Credit-normal accounts (Liabilities, Equity, Revenue):
   balance = total credits minus total debits.
3. A Reversing Entry applies the same logic (flipped amounts), so balances stay correct.

## Migration

- `Accounts` table (TenantId, Code, Name, AccountType, ParentAccountId, CurrentBalance,
  IsActive, Notes, audit columns). Unique on (TenantId, Code).
- `TenantAccountMappings` table (TenantId, MappingKey, AccountId, audit columns).
  Unique on (TenantId, MappingKey).
- `JournalEntries` table (TenantId, Reference, ReferenceType, ReferenceId, EntryDate,
  Description, Status, PostedAt, VoidedAt, audit columns).
- `JournalEntryLines` table (JournalEntryId, AccountId, DebitAmount, CreditAmount,
  Description, audit columns). FK to JournalEntry.

All with indexes on: AccountId (lines), ReferenceType+ReferenceId (entries),
TenantId+Code (accounts), TenantId+MappingKey (mappings).

## Permissions

- `AccountingView` — read accounts, journal entries, trial balance, general ledger
- `AccountingCreate` — create/update accounts, create draft journal entries
- `AccountingApprove` — post/void journal entries

## API

### Accounts
- `POST /api/v1/accounts` — CreateAccount (AccountingCreate)
- `GET /api/v1/accounts` — ListAccounts (AccountingView), filter by AccountType
- `GET /api/v1/accounts/{id}` — GetAccount (AccountingView)
- `PUT /api/v1/accounts/{id}` — UpdateAccount (AccountingCreate)

### Journal Entries
- `POST /api/v1/journal-entries` — CreateJournalEntry (AccountingCreate)
- `GET /api/v1/journal-entries` — ListJournalEntries (AccountingView)
- `GET /api/v1/journal-entries/{id}` — GetJournalEntry (AccountingView)
- `POST /api/v1/journal-entries/{id}/post` — PostJournalEntry (AccountingApprove)
- `POST /api/v1/journal-entries/{id}/void` — VoidJournalEntry (AccountingApprove)

### Reports
- `GET /api/v1/reports/trial-balance?from=&to=` — TrialBalance (AccountingView)
- `GET /api/v1/reports/general-ledger?accountId=&from=&to=` — GeneralLedger (AccountingView)

### Tenant Account Mappings
- `GET /api/v1/account-mappings` — ListMappings (AccountingView)
- `PUT /api/v1/account-mappings` — UpsertMapping (AccountingCreate)

## Events consumed

| Event | Source Module | Journal Entry Created |
|-------|--------------|----------------------|
| `SaleCompletedEvent` | Sales | Debit CashAndBank, Credit SalesRevenue + VATPayable |
| `SupplierBillCreatedEvent` | Purchasing | Debit InventoryAsset, Credit AccountsPayable |
| `SupplierBillPaidEvent` | Purchasing | Debit AccountsPayable, Credit CashAndBank |
| `SaleVoidedEvent` | Sales | Reversing entry (flip debits/credits of original) |

## Events raised

| Event | When |
|-------|------|
| `JournalEntryPostedEvent` | JE transitions Draft → Posted |
| `JournalEntryVoidedEvent` | JE transitions Draft → Void |

## Tests

### Unit tests
- Account creation invariants (Code required, unique per tenant, valid AccountType)
- JournalEntry balancing invariant (debits == credits, ≥2 lines)
- JournalEntryLine invariants (exactly one of debit/credit > 0)
- Status transition guards (Draft→Posted, Draft→Void, cannot post non-Draft)
- CurrentBalance update logic (Debit-normal vs Credit-normal accounts)
- TenantAccountMapping resolution
- Idempotency check (duplicate reference returns existing entry)

### Integration tests (blocked on Postgres)
- Full Sale→JournalEntry flow via event
- Full Purchase→Bill→Payment→JournalEntry flow
- Reversing entry on SaleVoided
- Tenant isolation (different tenants, different accounts)
- 403 for viewer role

## Future improvements (NOT implemented now)

- Automatic account mapping setup during tenant onboarding
- Period closing (lock prior periods)
- Currency conversion support
- Consolidated financial statements (Balance Sheet, P&L)
- Budget tracking per account
- Audit trail for balance changes
