# Full Implementation Plan — Receipt redesign (Jolinx reference mock)

All decisions locked from your answers: **both on-screen + thermal text**, **big header = tenant business name**, **tenant currency with 2 decimals**, **QR only (no barcode)**, **backend DTO extension allowed**. No schema migration, no new permissions (reuse `Receipts.View` / `Receipts.Print`), no domain changes — every field in the mock already exists in the domain, this is projection + rendering only.

---

## 0. Target receipt text (the contract everything else implements)

`Thermal80mmRenderer` output, 42 columns, English (SW = same structure, labels from `ReceiptLabels`):

```
*** REPRINT ***                    ← only when isReprint
------------------------------------------
*** SALE VOIDED ***                ← only when isVoided
------------------------------------------
Jolinx Superstore - Downtown       ← centered; businessName (bold on thermal)
26 LLX South, Downtown District,   ← centered address
Cityville, Country - 127830
Phone: +1 234 567 8900             ← omitted when null
Email: info@jolinx.com             ← omitted when null
Tax No: TAX123456789               ← omitted when tin null
------------------------------------------
Receipt No.     : RCP-250601-000123
Date / Time     : 01-Jun-2025 10:24 AM
Cashier         : John Doe         ← omitted when null
Customer        : Walk-in Customer ← null → "Walk-in Customer"
------------------------------------------
Item             Qty     Price    Total
------------------------------------------
Paracetamol 500mg    1     2.50     2.50
Vitamin C 1000mg     2     5.00    10.00
Face Mask (Pack of 10) 1    4.50    4.50   ← name truncated with … if needed
------------------------------------------
Subtotal                   TZS 23.75
Discount (5%)             -TZS 1.19        ← only when discount > 0
Tax (VAT 10%)              TZS 2.26        ← FIX: never emitted today
==========================================
GRAND TOTAL               TZS 24.82        ← '=' rule, bold on thermal
------------------------------------------
Paid Amount               TZS 24.82
Payment Method            Card             ← payments.map(method).join(' + ')
Transaction ID      TXN-56587451236         ← first non-null reference; row omitted for cash
Change                    TZS 50.00         ← only when > 0
------------------------------------------
Verification: a1b2c3d4                      ← only when fiscalHash non-null
------------------------------------------
[QR CODE]                                   ← only when qrPayload non-empty
RCP-250601-000123                           ← centered caption (replaces barcode caption)
------------------------------------------
Thank you for shopping with us!
Goods once sold will not be taken back.
Visit us again!
Jolinx ERP                                  ← small product-brand line (footer)
```

**Formatting rules (deltas from today):**
- **Money:** `formatMoney(amount, symbol: receipt.currency, alwaysDecimals: true)` → `TZS 23.75`, `-TZS 1.19` for discount. Item-table columns show **bare** grouped amounts (`2.50`, `1,250.00`, no currency code) — column width is the binding constraint on 42 chars; symbol appears on every totals/payment row. This is a deliberate, noted deviation from the mock (`$` is 1 char, `TZS` is 3).
- **Date:** `dd-MMM-yyyy hh:mm a` → `01-Jun-2025 10:24 AM` (12-hour + AM/PM, hand-rolled, replacing `dd MMM yyyy HH:mm`).
- **Discount %:** client-computed `discountAmount / subtotal * 100`, rounded to integer → `Discount (5%)`.
- **Tax %:** client-computed effective rate `taxAmount / (subtotal − discountAmount) * 100`, 1 decimal, trailing `.0` stripped → `Tax (VAT 10%)`. Derived from fields already in the DTO — **no per-line `TaxRate` field needed** (dropped from the earlier draft; the mock has no per-line tax column).
- **Item columns are dynamic**, computed per receipt: `totalW` = max(line totals, col label), `priceW` = max(unit prices, label), `qtyW` = max(qty strings, label), `nameW = 42 − qtyW − priceW − totalW − 3`. qty/price/total right-aligned in their columns; name left, truncated with `…` when `nameW` is exceeded. Header row uses the same widths.
- **Swahili labels added** to `ReceiptLabels`: `colItem` (Bidhaa), `colQty` (Kiasi), `colPrice` (Bei), `colTotal` (Jumla), `receiptNo` (Risiti Na.), `dateTime` (Tarehe / Muda), `cashier` (Muuzaji), `customer` (Mteja), `paidAmount` (Lilipwa), `paymentMethod` (Njia ya Malipo), `transactionId` (Kitambulisho cha Muamala), `walkIn` (Mteja wa kupita-njia), `email`/`phone`/`taxNo`, footer policy lines, `scanHint`.

---

## Task 001 — Backend: extend the receipt preview projection

**Files:**
- `backend/src/Application/Features/Receipts/Dtos/ReceiptDtos.cs`
- `backend/src/Application/Features/Receipts/Queries/GetReceiptPreviewQuery.cs`
- `backend/tests/BusinessOS.Tests/Integration/ReceiptEndpointsTests.cs`

**Changes:**

1. `ReceiptPreviewDto` gains: `string? Email`, `string Currency`, `string? BranchName`, `string? CashierName`, `string? CustomerName`.
2. `ReceiptPaymentDto` gains: `string? Reference`.
3. Handler: inject `IUserRepository` and `IBranchRepository` (both already registered in `Infrastructure/DependencyInjection.cs:34-35`), then project:
   ```csharp
   CashierName: (await _users.GetByIdAsync(tenantId, sale.CashierId, ct))?.FullName,
   BranchName: (await _branches.GetByIdAsync(tenantId, sale.BranchId, ct))?.Name,
   CustomerName: sale.CustomerName,
   Email: identity?.Email,
   Currency: sale.Currency,
   // payments:
   new ReceiptPaymentDto(p.Method.ToString(), p.Amount, p.Reference)
   ```
   All lookups are tenant-scoped (`GetByIdAsync(tenantId, …)`), null-safe (row deleted / offline-created sale → null → renderer omits the row). No other handler changes; `BuildQrPayload` unchanged.
4. **Integration tests** (extend `GetReceiptPreview_ForCompletedSale_ReturnsPreviewWithMetadata`): assert `currency` non-empty, `cashierName` non-empty (registration user), `branchName` non-empty (default branch), `customerName` null present (`TryGetProperty`), `payments/0/reference` key exists. Plus one new fact: sale posted with a payment carrying `reference` → preview returns it.

**Verify:** `dotnet build --warnaserror`, `dotnet test --filter "FullyQualifiedName~Receipt"` (needs local Postgres on :5432).

---

## Task 002 — Flutter: model + cache extension

**Files:**
- `lib/features/receipts/domain/receipt_preview.dart`
- `lib/core/storage/receipt_cache.dart`
- `lib/features/sales/data/receipt_printer_service.dart` (`saleToReceipt`)
- `test/features/receipts/receipt_preview_test.dart`

**Changes:**
1. `ReceiptPreview`: add `email`, `branchName`, `cashierName`, `customerName` (`String?`) and `currency` (`String`, `fromJson` default `'TZS'` for pre-upgrade cache files). `ReceiptPayment`: add `reference` (`String?`).
2. `ReceiptCache.put`: write the five new payment/preview keys — otherwise the cache round-trip silently drops them (it hand-builds the JSON map).
3. `saleToReceipt` (offline/fallback path): set `currency: sale.currency`, `customerName: sale.customerName`, **`isVoided: sale.isVoided`** (currently hardcoded `false` — latent bug), leave cashier/branch/email null (rows degrade to omitted).
4. Tests: new-fields parsing + old-JSON-without-new-keys still parses.

**Verify:** `flutter analyze`, `flutter test test/features/receipts`.

---

## Task 003 — Register the RobotoMono font

**File:** `pubspec.yaml`

`assets/fonts/RobotoMono-Regular.ttf` and `-Bold.ttf` exist but only `VT323` is registered — every receipt widget requesting `fontFamily: 'RobotoMono'` silently falls back to a proportional font, which misaligns every column. Add:

```yaml
    - family: RobotoMono
      fonts:
        - asset: assets/fonts/RobotoMono-Regular.ttf
        - asset: assets/fonts/RobotoMono-Bold.ttf
          weight: 700
```

**Verify:** `flutter pub get` + `flutter analyze`.

---

## Task 004 — Rewrite `Thermal80mmRenderer`

**Files:**
- `lib/features/receipts/domain/receipt_renderer.dart` (main work)
- `lib/shared/format/money.dart` (add `alwaysDecimals` flag — default `false`, zero impact on existing call sites)
- `lib/features/receipts/data/receipt_providers.dart` (locale-aware language: watch `localeControllerProvider`, `sw` → `ReceiptLanguage.swahili`)
- `lib/features/sales/data/receipt_printer_service.dart` (ctor language from the same locale source; `isVoided: sale.isVoided` via task 002; ESC/POS rules below)
- `lib/features/receipts/domain/receipt_qr.dart` (`_formatTotal` hardcodes `TSh` → use `receipt.currency` via `buildQrPayloadFromReceipt`; keep 0-dp in QR payload, it's verification text not a ledger)

**Renderer `render()` structure (replacing lines 76–154):**
1. reprint marker + `-` rule; void marker + `-` rule (unchanged behaviour).
2. **Header, centered:** `businessName` (own line, banner), `branchName` if present, address, `Phone: …`, `Email: …`, `Tax No: …` — each omitted when null/empty.
3. **Meta rows** via `_row('$label :', value)`: Receipt No., Date / Time (new format), Cashier (skip if null), Customer (`customerName ?? walkInLabel`).
4. **Items:** header row (`Item/Qty/Price/Total`) built with the same `_itemColumns()` widths as data rows; one row per line; then `-` rule.
5. **Totals:** Subtotal; Discount `(pct%)` with `-` prefix when > 0; Tax `(VAT n%)` when `taxAmount > 0`; then `=` × 42 rule; `GRAND TOTAL`.
6. **Payments:** Paid Amount, Payment Method, Transaction ID (first non-null `reference`, row omitted when none), Change when > 0.
7. **Fiscal:** `Verification:` **only when `fiscalHash` non-null/non-empty** (aligns with the mock — today it always prints `---`).
8. **QR:** `[QR CODE]` block **only when `qrPayload` non-empty** (today unconditional — this also fixes a stale test expectation and matches the ESC/POS guard), followed by centered `saleNumber` caption.
9. **Footer:** thank-you, two policy lines, `Jolinx ERP`.

**Helpers:** `_formatDate` (12h + AM/PM), `_money` (currency + always 2 dp), `_moneyBare` (2 dp, no symbol, for item columns), `_formatQty` (whole → int, else 2 dp), `_itemColumns()` (dynamic widths), keep `_row`/`_center`, retire `_formatMoneyShort`.

**ESC/POS rules in `buildEscPosBytes` (`receipt_printer_service.dart:33-82`):**
- Header mode **ends at the meta label line**, not at the first separator (fixes an existing latent bug: today the separator after the reprint/void watermark exits header mode, so a watermarked receipt prints its business block left-aligned). Treat `Receipt No.` / `RECEIPT:` / `RISITI:` as the terminator; watermark lines stay centered+bold.
- Bold only the business-name line inside the header (first non-watermark line); address/email stay centered non-bold.
- `isSeparator`: also match `===` (the GRAND TOTAL rule).
- `isTotal`: add `GRAND TOTAL` (today only `TOTAL`/`JUMLA` prefixes — `GRAND TOTAL` starts with `GRAND` and would print left/unbold).
- Center the QR caption: `trimmed == receipt.saleNumber`.
- Bold the item-header row: `trimmed.contains('Qty') || trimmed.contains('Kiasi')`.
- `[QR CODE]` raster hook unchanged (renderer still emits the exact marker line).

**Verify:** analyze + the tests in task 005.

---

## Task 005 — Renderer/model tests

**File:** `test/features/receipts/receipt_preview_test.dart`

1. **Fix stale expectations** (currently out of sync with the implementation):
   - `qrPayload` missing → `''` not `null`; `[QR CODE]` written only when payload non-empty (assert both branches).
   - `buildQrPayload` never returns null → replace the two `isNull` tests with "contains sale info without fiscal hash".
   - `Thibitisho:` test → default renderer is English → assert `Verification:`; add a Swahili-renderer variant asserting `Thibitisho:`.
2. **New assertions:** meta block (`Receipt No.`, `Date / Time`, Cashier, Customer rows); item header row + unit price **and** line total on data rows; `Subtotal`, `Discount (5%)` with `-` sign, `Tax (VAT 10%)` emitted (the bug fix); `=` rule + `GRAND TOTAL`; `Transaction ID` present/absent; `Paid Amount`; currency `TZS 24.82` style (2 dp always); date `07-Sep-2026 10:30 AM`; email + `Tax No:` in header; centered `Jolinx ERP` footer line; every rendered line ≤ 42 chars (width invariant test over a long fixture).
3. Extend `_createTestReceipt` fixture with email/branch/cashier/customer/currency/payment reference.

**Verify:** `flutter test test/features/receipts`.

---

## Task 006 — On-screen ticket widget + page wiring

**Files:**
- **New** `lib/features/receipts/presentation/widgets/receipt_ticket_card.dart`
- `lib/features/sales/presentation/pages/receipt_preview_page.dart`
- `lib/features/sales/presentation/pages/sale_success_page.dart`
- **New** `test/features/receipts/receipt_ticket_card_test.dart`

**Widget** (`ReceiptTicketCard`, stateless, no providers — UI only, per the no-mixed-layers rule):
- Inputs: `ReceiptPreview receipt`, `ReceiptLanguage language` (or just receipt — labels from `ReceiptLabels`), optional `bool dense` (success page), optional `Widget? trailing` (QR block).
- Sections mirroring the mock: centered bold `businessName` (18–20 px), branch/address/phone/email/tax-no centered stack; `Divider`; meta `Row`s (label left, value right, RobotoMono 13); `Divider`; items table — bold header row with the same flex column ratios as the text renderer, rows showing name (expanded, `TextOverflow.ellipsis`) / qty / unit price / line total right-aligned; `Divider`; totals rows with **`GRAND TOTAL` at 16 px `w700`** under a `=`-style rule (double `Divider` or a `Container` of height 2 in the theme's outline color — no hardcoded colors, use `AppColors`/`Theme`); payments block; `Divider`; centered thank-you; `QrImageView` (only when payload non-empty) + centered `saleNumber` caption + scan hint; footer policy lines + small `Jolinx ERP`.
- Money/date/percent use the **same helpers as the text renderer** (extract them to a shared `lib/features/receipts/domain/receipt_format.dart` imported by both — no duplicated business formatting, per ArchitectureRules).

**Pages:**
- `ReceiptPreviewPage._buildReceiptContent` → replace the raw `Text(receiptText)` block with `ReceiptTicketCard(receipt: receipt)`; AppBar actions (print/copy/share/save) untouched — they still use `_buildReceiptText()` (renderer).
- `SaleSuccessPage`: fix `businessName: 'Business'` → `_businessName` (the getter exists at line 188 but `build` hardcodes `'Business'`); replace the monospace text card with `ReceiptTicketCard(receipt: receipt, dense: true)` wrapped in `Flexible(child: SingleChildScrollView(...))` so a tall ticket can't overflow the centered column; keep QR at a smaller size.

**Widget test:** pump the card with the fixture → expect business name, `Receipt No.` value, item header labels, unit price + line total, `GRAND TOTAL`, transaction ID, cashier/customer rows, `QrImageView` present (and absent for empty payload).

**Verify:** `flutter analyze`, `flutter test test/features/receipts test/features/sales`.

---

## Task 007 — Unify the two receipt builders (retire the legacy one)

**Files:**
- `lib/features/sales/presentation/pages/sale_success_page.dart:272-278`
- **Delete** `lib/features/sales/domain/receipt.dart`
- `test/features/sales/cart_and_receipt_test.dart` (group `buildReceiptText`, lines 251–306)

**Changes:**
1. `_shareAsText()` → `ref.read(receiptPrinterServiceProvider).buildReceiptText(receipt: printerService.saleToReceipt(sale: widget.sale, businessName: _businessName))` — the service method already delegates to the locale-aware renderer. One ticket per sale, guaranteed.
2. Delete `lib/features/sales/domain/receipt.dart` (imported only by those two files — confirmed by grep).
3. Migrate the `buildReceiptText` group to renderer-based tests: build `SaleDto` → `saleToReceipt` → render with Swahili labels, assert equivalent content under the new contract: `Duka la Mama`, `Risiti Na. : S-2026-000001` (or `Receipt No.` — pick the renderer's EN default and assert against it), item rows with qty/price/total, `Jumla ndogo: TZS 7,394.92`, `Kodi (VAT 16%)`-style label when tax > 0, `Punguzo`, `JUMLA: TZS 8,720`, `Malipo: Cash`. Date assertion updates to the new format.

**Verify:** `flutter analyze`, full `flutter test`.

---

## Task 008 — Wire the reprint watermark (currently dead code)

**Files:**
- `lib/features/sales/presentation/pages/receipt_preview_page.dart`
- `lib/features/sales/presentation/pages/sale_success_page.dart`

**Changes:**
1. **Render with `isReprint: receipt.printCount > 0`** everywhere the preview is rendered (page card, copy/share/save text, and `printToDevice`/`buildEscPosBytes` — add an `bool isReprint = false` param threaded into `_renderer.render`).
2. **After a successful print**, `try { await receiptRepository.recordPrint(saleId: …, type: printCount == 0 ? PrintType.original : PrintType.reprint) } catch (_) {}` — fire-and-forget, never blocks or fails the print UX. On `ReceiptPreviewPage` then bump local state (`printCount+1`, `isReprint = true`) so a second print in the same session shows the watermark.
3. `SaleSuccessPage` records `PrintType.original` for a fresh sale (server count starts at 0); its own re-renders keep `printCount: 0` from `saleToReceipt` — the watermark appears on the next `ReceiptPreviewPage` open, which is where reprints actually happen. Note this in the task log.
4. Failures are swallowed (offline) — the watermark is a nicety, the audit row is the goal.

**Verify:** existing `ReceiptEndpointsTests.RecordPrintEvent_*` cover the server; add a Flutter test that a preview with `printCount: 2` renders `*** REPRINT ***` end-to-end through the page (repo override with a fixture).

---

## Task 009 — Docs, changelog, verification sweep

**Files:** `specs/receipts.md` (**new** — the receipts module shipped without a spec; short spec covering preview/print/reprint/layout-seed endpoints, DTO contract, layout sections, renderer rules), `specs/sales-pos.md` (cross-link), `changelog/CHANGELOG.md` (new version entry), `memory/project.md` (new milestone paragraph), `tasks/mvp/TASKS.md:36` (M7 status: preview/copy/save/print/reprint now complete).

**Final verification (all must pass):**
```
flutter analyze && flutter test
cd backend && dotnet build --warnaserror && dotnet format --verify-no-changes
dotnet test --filter "FullyQualifiedName~Receipt"        # Postgres required
```

---

## Not in scope (explicit)

Code128 barcode · interpreting the stored layout `specJson` (renderer stays canonical; the seed JSON is documentation) · fiscal adapter / `FiscalSigner.GenerateQrPayload` wiring · SMS/email receipts · money-account auto-posting (M10.2 finding) · `docs/DEPENDENCY_MAP.md` refresh (pre-existing staleness).

**Risk register:** 42-char width with 4 columns → dynamic sizing + width-invariant test; long TZS amounts shrink `nameW` → `…` truncation with a `nameW ≥ 6` guard; ESC/POS heuristics → covered by the header-terminator fix + marker rules above; task 007 touches M4 tests → approved here as its own task.

Approve and I start with Task 001 (backend DTO + integration tests).