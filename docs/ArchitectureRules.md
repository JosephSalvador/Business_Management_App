# Architecture Rules

> Read before every task. These are non-negotiable and "almost never change."

## Code rules

- Never duplicate business logic. Extract to a shared service or engine.
- Never access the database directly from UI or controllers. Go through `Application` use cases.
- Modules never reference other modules — only platform contracts.
- Every API returns `Result<T>` (or a problem-details envelope on failure).
- Every table has a UUID primary key.
- Every table has `CreatedAt` / `CreatedBy` and `UpdatedAt` / `UpdatedBy`.
- Every mutation creates an audit log entry (actor, action, entity, tenant, old/new).
- Every mutation that raises side effects persists domain events (outbox) in the same transaction.
- Every feature has permissions defined in `PermissionNames` and enforced by the RBAC pipeline.
- Every feature has unit tests; cross-module flows have integration tests.
- No feature merges without documentation (spec + API + changelog updated).
- No TODOs in production code.
- No magic numbers, no hardcoded colors, no hardcoded URLs, no hardcoded business rules.
- Everything configurable: tax rules, numbering sequences, currencies, units, dynamic fields, UI strings.
- API-first: a REST endpoint exists before the UI screen.

## Client architecture rule

**One Flutter codebase, all platforms.** This is locked (2026-08-31).

- All client code lives in `frontend/jolinx_app/`.
- Platform-specific code lives in `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`.
- Shared code (auth, API, models, state, validation, localization, theme, components, navigation,
  error handling, permissions, business workflows, offline storage, synchronization, testing)
  lives in `lib/`.
- **Never create separate projects** for web, desktop, or mobile. One project, one codebase.
- Platform-specific implementations (receipt printer, camera, file system, OS APIs) go behind
  common Dart interfaces in `lib/core/platform/`.
- One codebase ≠ one UI. Each platform adapts to its device.

## Progressive complexity rule

**The system must hide complexity, not capability.** Users never need to understand how the
system works internally to accomplish a business task.

- No database language in UI. Use business actions: "Add stock" (not "Adjustment Transaction"),
  "Fix stock" (not "Stock Reconciliation"), "Stock history" (not "Stock Movement"), "Store"
  (not "Warehouse Location").
- Small businesses get a simple interface. Growing businesses progressively unlock more
  capability. Advanced businesses can access deeper controls without changing the platform.
- Smart defaults do most of the work. Default warehouse, default price, default unit. The
  user confirms, not configures.
- "Do" and "Manage" are separated by role. Cashiers see Sell/Add stock/Record expense.
  Owners see Products/Prices/Warehouses/Staff/Reports/Settings.
- Negative stock informs, never blocks. Show "Stock is now -4. You can correct later."
  Sales always succeed; stock is advisory.
- **Purchase vs Expense — strict separation.** Two distinct business events, never blurred:
  - **Purchase** = "Nimenunua bidhaa" — acquiring inventory from a supplier. Increases stock,
    affects supplier balance/payable, may affect inventory cost.
  - **Expense** = "Nimetumia pesa" — money spent to operate the business (rent, transport,
    internet, airtime, staff lunch, government fees). Money out only, no stock increase.
  - Users enter through the correct action immediately. No generic "Money Out" button that
    forces a secondary choice. The system handles accounting consequences underneath.

## Business data integrity rule

**Every number must have a story.** The system collects information at the moment the user
has it, so reports are trustworthy later.

**Enforcement model — not everything blocked at the same strength:**

| Area                        | Enforcement                       | Why                                                 |
| --------------------------- | --------------------------------- | --------------------------------------------------- |
| Product cost price          | Required                          | Margin and stock valuation depend on it             |
| Purchase source/supplier    | Required                          | Establishes where stock came from                   |
| Purchase unit cost          | Required                          | Needed for inventory valuation                      |
| Purchase quantity           | Required                          | Obvious transaction requirement                     |
| Money Account               | Required                          | Prevents unexplained money                          |
| Expense category            | Required                          | Makes reports meaningful                            |
| Opening stock cost          | Required                          | Establishes inventory value                         |
| Sale void reason            | Required                          | Protects audit trail                                |
| Customer on cash sale       | Optional                          | Don't create unnecessary friction                   |
| Supplier for every purchase | Allow "Walk-in Supplier"          | Small shops may buy without formal supplier records |
| Stock adjustment            | Requires reason                   | Not every stock change is a purchase                |
| Selling price               | Required before selling           | But allow different price lists                     |

**Stock increases are guided, not blindly blocked.** The user picks a reason:

> "Unaongeza stock kwa sababu gani?"
>
> 🛒 Nimenunua (Purchase → requires supplier + cost)
> ↩️ Return (Customer return)
> 🏭 Production
> 🔄 Transfer (Internal)
> 📦 Opening Stock (requires cost)
> 🛠️ Adjustment (requires reason)

The system enforces different fields based on the reason.

**UX principle — never say "You can't."**

Instead of: "Cannot save. Cost price is required."

Use: "Bei ya kununua inahitajika. Tutaweza kukokotoa thamani ya stock na faida yako kwa usahihi."
     `Bei ya kununua: TZS ______`

**Collect at the moment, not later.** When they receive goods, they know the cost NOW.
When they spend money, they know the category NOW. When they void a sale, they know the
reason NOW. Don't wait until Reports to discover the data is missing.

## Database schema strategy

- All tables live in the `public` schema during Platform and Foundation phases to keep migration
  complexity low.
- Every EF Core entity mapping declares its schema explicitly with
  `ToTable("<Table>", "<Schema>")` — never rely on provider defaults.
- Table names and schemas come from the catalog in
  `backend/src/Infrastructure/Persistence/TableNames.cs`, grouped by bounded context
  (Organization, Identity, Platform, ...). Mappings reference these constants only.
- A bounded context moves into its own PostgreSQL schema by changing its schema constant in
  `TableNames.cs` and generating one migration. Do not split schemas until Sales, Inventory,
  and Accounting are stable.

## Localization strategy (tax, fiscal, revenue authorities)

Country-specific behavior is a plug-in, never core logic. This is the Odoo `l10n_*` pattern:
the core tax engine is agnostic and the database decides which plug-in applies.

- Every localization lives under `backend/src/Localizations/<Country>/` (e.g. `Tanzania/Tax/`,
  `Tanzania/Fiscal/`, `Kenya/Tax/`). The core references `ITaxCalculationStrategy` (and standard
  domain events), never a country by name.
- The platform selects a localization at sale time through the `CalculationStrategyKey` stored on
  the tenant regime's `TaxRule` rows. The core blindly asks DI for the strategy; no `if
  (country == "TZ")` switches anywhere.
- **No core changes for a new country.** A localization only implements the strategy contract or
  consumes standard domain events. Never alter the `Sale` aggregate to add a country-specific
  column.
- **Localization never blocks checkout.** Fiscal/revenue-authority integration (e.g. TRA VFD) runs
  as an asynchronous outbox consumer, strictly opt-in per tenant. A government API being down can
  never reject or delay a sale.
- **Rely on the snapshot.** Localizations read from `TaxLineSnapshot` and the `Sale` fiscal
  placeholders (e.g. `FiscalReceiptNumber`) — never recompute the totals on the fly.
- Core fallback stays `DefaultPercentageTaxStrategy` (`Simple`), which covers the majority of
  jurisdictions. Shipped localizations: `TZ_DUAL_VAT` in `Localizations/Tanzania/Tax/`.

## Process rules

- Read `docs/ArchitectureRules.md` + `docs/CodingStandards.md` + the feature spec before coding.
- Create an implementation plan and get approval before implementing a feature.
- Implement one small task at a time. Run analyzers and tests. Fix failures.
- Produce a completion report; update documentation; suggest the next task.
- OpenCode must never invent architecture, rename unrelated files, modify completed modules
  without a task, skip tests/docs, ignore warnings, change standards, or commit unverified code.

## Definition of Done (all must be true)

- Requirements implemented
- No analyzer warnings
- Tests pass
- Manual checklist passes
- Documentation updated (spec/API/changelog)
- Database migration created
- Localization added
- Audit logging added
- Permissions added
- Responsive UI verified
- Offline mode + sync verified
- Error handling verified

## Business Data Integrity

**Every number must have a story.** This rule enforces that the business can always explain its numbers.

### Enforcement model

| Data point | Level | Rule |
|---|---|---|
| Product cost price | Required | Every physical product (goods) must have a cost price. Services exclude cost price. |
| Sale line unit cost | Snapshot | Cost price is copied onto each SaleLine at sale time from `Product.CostPrice`. Immutable after sale. |
| COGS | Derived | `SUM(SaleLine.UnitCost × Quantity)` — never approximated from POs alone. |
| Stock increase reason | Required | Every stock increase (adjustment or opening) requires a reason type from the enum. |
| Stock unit cost | Optional | Cost per unit can be provided on stock adjustments and opening stock. |
| Expense category | Required | Every expense must have a category. Default categories are seeded per tenant. |
| Sale void reason | Required | Voided sales must include a reason string. |

### Stock reason types

When stock increases, the user picks a reason from: **Purchase**, **Return**, **Opening Stock**, **Adjustment**, **Transfer**, **Production**.

### Product cost price flow

1. **Product creation**: Cost price is required for goods, forbidden for services.
2. **Sale time**: `Product.CostPrice` is snapshot onto `SaleLine.UnitCost` — immutable after sale.
3. **COGS calculation**: `SUM(SaleLine.UnitCost × Quantity)` — uses snapshotted values.
4. **Reporting**: Gross profit = Revenue - COGS (using snapshotted cost).

### UX principles

- Never say "You can't" — guide the user to the right action.
- Collect cost information at the moment the user has it (product creation, stock receipt).
- If a number can't be explained, surface it as a warning, not a blocker.
