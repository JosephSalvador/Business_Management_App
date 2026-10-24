# Feature Spec — Receipts (preview / share / print / reprint / layout)

> Ships with `docs/plans/2026-09-25-receipt-redesign-plan.md`. Backend preview/print was
> delivered in M4 (`20260907123456_AddReceiptRenderingEngine`); this spec covers the redesign
> that makes the on-screen ticket and the thermal slip one artifact. Status: implemented &
> verified 2026-09-25.

## Feature

Render a completed sale as a customer-facing receipt — on screen, as text, as PDF and on a
Bluetooth thermal printer — in English or Swahili, using the tenant's currency, with a
verifiable QR payload and an audited print history.

## Purpose

The receipt is the only artifact the customer takes away from a sale. Before the redesign the
platform had two different receipts (a legacy `sales/domain/receipt.dart` builder and the
thermal renderer), no unit price column, no discount percentage row, no payment
reference, no reprint watermark (dead code) and no print audit rows. This feature makes the
receipt a single, tested, localized artifact.

## Business rules

- **Single source of truth for layout:** `lib/features/receipts/domain/receipt_renderer.dart`
  (`Thermal80mmRenderer`) emits every line already positioned inside `receiptLineWidth` = 42
  columns. The printer sends the text verbatim — it only adds bold emphasis and the QR raster
  image, because re-centering in ESC/POS would double-shift a header the renderer already
  centered.
- **Shared formatting:** money, date, quantity and percentage strings come from
  `lib/features/receipts/domain/receipt_format.dart` for both the renderer and the on-screen
  `ReceiptTicketCard` — no duplicated business formatting across layers.
- **Width invariant:** every rendered line is padded/truncated to exactly 42 characters
  (`_fit`), enforced by a test over a long fixture.
- **Money:** the tenant's ISO currency code is printed as-is (`TZS 23.75`) with two decimals
  always, so columns line up. The QR payload keeps a whole-number total (verification text,
  not a ledger figure).
- **Section order:** reprint/void watermark → centered business header (name, branch,
  address, `Phone:`, `Email:`, `TIN:` — each omitted when empty) → meta block (Receipt No.,
  Date/Time `dd-MMM-yyyy hh:mm a`, Cashier when present, Customer or walk-in label) → item
table (`Item | Qty | Price | Total`, name column absorbs the remainder and truncates with
   `…`) → Subtotal, `Discount (n%)` with a `-` sign → `=` rule →
   `GRAND TOTAL` → Paid Amount, Payment Method, Transaction ID (first payment reference; row
   omitted when none), Change when > 0 → `Verification:` only when a fiscal hash exists →
   `[QR CODE]` marker + centered sale number only when a payload exists → 4 footer lines.
- **No tax on the receipt:** Tax and VAT are removed across all retail workflows in the app, so
   the ticket never prints a tax row and never derives a tax percentage. Discount percentages stay.
- **Localization:** labels come from `ReceiptLabels` keyed by `ReceiptLanguage`
  (`receiptLanguageForCode(locale.languageCode)`). Both `thermalRendererProvider` and
  `receiptPrinterServiceProvider` watch the app locale, so screen, text and print agree.
- **Reprint watermark:** `*** REPRINT ***` (Swahili void marker `*** MUAMALA UMEFUTWA ***`)
  renders when `isReprint` is true. Pages pass `isReprint = printCount > 0` plus their own
  same-session print counter, because the server count only catches up after `recordPrint`.
- **Print audit:** after every successful print the page fire-and-forget
  `ReceiptRepository.recordPrint(saleId, type)` (`Original` on the first print, `Reprint`
  after). Failures are swallowed — the watermark is a nicety, the audit row is the goal.
- **One builder:** `ReceiptPrinterService.saleToReceipt` is the only offline/just-closed
  path from `SaleDto` to a ticket. The legacy `sales/domain/receipt.dart` builder is deleted.
- **Frozen identity (backend):** a reprint rebuilds the ticket from `ReceiptMetadata`'s
  business-identity snapshot and the sale snapshot, never from live tenant settings.

## Screens (Flutter)

- `ReceiptPreviewPage` (`/receipt-preview/{saleId}`) — `ReceiptTicketCard` inside a card;
  AppBar actions print (Android), copy, share, save `.txt`. Falls back to `SaleDto.number`
  when the preview API is unreachable.
- `SaleSuccessPage` — `ReceiptTicketCard(dense: true)` in a scrollable card directly after a
  sale; sell again / print / share.
- `lib/features/receipts/presentation/widgets/receipt_ticket_card.dart` — stateless,
  provider-free UI twin of the renderer: header, meta, item table, totals under a 2 px rule,
  payments, verification, footer, `QrImageView` + caption + scan hint (only when a payload
  exists).

## API (backend)

| Endpoint | Method | Permission | Notes |
|---|---|---|---|
| `/api/v1/receipts/{saleId}/preview` | GET | `Receipts.View` | `ReceiptPreviewDto` (below) |
| `/api/v1/receipts/{saleId}/print` | POST | `Receipts.Print` | body `{ type, deviceId?, notes? }` → `PrintEventRecordedDto` |
| `/api/v1/receipts/layouts/seed` | POST | `Receipts.ManageLayouts` | idempotent default thermal layout |
| `/api/v1/receipts/layouts` | GET | `Receipts.View` | active layouts for the tenant |

`ReceiptPreviewDto`: `saleId`, `saleNumber`, `saleDate`, `subtotal`, `taxAmount`,
`discountAmount`, `totalAmount`, `amountPaid`, `change`, `printCount`, `isReprint`,
`isVoided`, `hasMetadata`, `businessName`, `tin?`, `address?`, `phone?`, **`email?`**,
**`branchName?`**, **`cashierName?`**, **`customerName?`**, **`currency`**, `layoutId?`,
`fiscalHash?`, `qrPayload`, `lines[]`, `payments[]` where each payment is
`{ method, amount, reference? }` (**`reference` new**).

Bold fields are the 2026-09-25 extension: identity/sale projection written by
`GetReceiptPreviewQuery` (branch + user display names, customer, tenant currency, first
non-empty tender reference) so the ticket has no "Business"/"Walk-in" placeholders.

## Database

No migration in this redesign — it reuses the M4 schema:
`ReceiptPrintEvents` (immutable audit: `SaleId`, `TenantId`, `PrintedByUserId`, `PrintedAt`,
`Type` original/customerCopy/reprint, `LayoutVersionId?`, `DeviceId?`, `Notes?`),
`ReceiptMetadata` (frozen `BusinessIdentitySnapshot`, `FiscalHash?`), `ReceiptLayouts`
(`LayoutId`, `Version`, `IsActive`, `SpecJson?`). `specJson` is documentation only — the
renderer stays canonical.

## Validation

- Preview 404s for unknown/other-tenant sales; print requires a completed sale.
- `POST /print` `type` must parse to `PrintType { Original = 0, CustomerCopy = 1,
  Reprint = 2 }`.
- Flutter: `ReceiptPreview.fromJson` defaults `currency` to `TZS` and `qrPayload` to `''` so
  pre-upgrade cache files keep parsing (never `null`).

## Permissions

`Receipts.View` (preview + list layouts), `Receipts.Print` (record print events),
`Receipts.ManageLayouts` (seed). No new permissions were added; existing roles keep their
grants.

## Events

No new domain events. `ReceiptPrintEvent` rows are written directly through
`IReceiptPrintEventRepository` (write-once, never updated). `SaleCompletedEvent` → outbox →
notification path that queues receipt notifications is unchanged.

## Tests

- `test/features/receipts/receipt_preview_test.dart` — model round-trip (incl. old JSON
  without new keys), every renderer section, EN + SW labels, QR branches (marker present /
  absent, payload with and without fiscal hash, currency), and the 42-column width
  invariant over a long fixture.
- `test/features/receipts/receipt_ticket_card_test.dart` — widget: header/meta/item table,
  totals + transaction id, footer + `QrImageView`, QR absent on empty payload, reprint
  watermark, Swahili labels.
- `test/features/sales/cart_and_receipt_test.dart` — `saleToReceipt` → renderer (Swahili),
  replacing the deleted legacy builder's group.
- `backend/tests/BusinessOS.Tests/Integration/ReceiptEndpointsTests.cs` — preview identity
  fields (email/currency/branch/cashier/customer), payment reference, metadata, print events.

## Offline & sync

The preview is fetched once and cached by `ReceiptCache` (`toJson`/`fromJson`, so new fields
round-trip). Print/share/save work from the cached receipt; `recordPrint` failures are
swallowed when offline and the next successful print re-records. `saleToReceipt` covers the
just-closed/offline sale that has not been re-read from the API (branch/cashier/email are
null there → the rows degrade to omitted, never to placeholder text).

## Future improvements

- Interpreting the stored layout `specJson` (renderer stays canonical for now).
- Fiscal adapter wiring for `FiscalSigner.GenerateQrPayload` and a hosted verification URL
  (`QrConfig.baseUrl`).
- Code128 barcode, SMS/email receipts, per-tenant logo, A5/A4 layouts.
