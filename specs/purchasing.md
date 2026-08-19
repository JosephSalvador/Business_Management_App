# Feature Spec — Purchasing (Slice 8)

## Feature

A complete procurement module: suppliers, purchase orders (POs), goods-received notes
(GRNs), supplier invoices/bills, and supplier payments. Purchasing drives stock-in
(OpeningStock/TransferIn movements) and creates accounts-payable liability.

## Purpose

Purchasing is the inbound counterpart to Sales. It completes the buy→sell cycle:

```
Purchase Order → Goods Received (stock increases) → Supplier Bill (AP liability)
→ Supplier Payment (cash decreases, AP settles)
```

- Enables reorder workflows, supplier management, and cost tracking.
- Goods receipt auto-creates OpeningStock movements (or adjusts existing balances).
- Supplier bills feed into Accounting (journal entries, AP ledger).
- Supplier payments support cash, bank transfer, and mobile money.

## Sub-slices

| Slice | Scope |
|-------|-------|
| 8a | Suppliers + PO domain + repository + migration |
| 8b | Create/Receive/Cancel PO commands + endpoints |
| 8c | Supplier bills + payments |
| 8d | Integration tests + docs |

## Business rules

### Supplier

1. `Supplier` is a simple entity: Name (required ≤200), ContactName, Email, Phone,
   Address, TIN, IsActive, Notes.
2. Unique constraint: `(TenantId, Name)`.
3. Suppliers are soft-deactivated (IsActive), never deleted.

### Purchase Order (PO)

1. A PO is created in `Draft` status. It can be **Submitted** (→ `Submitted`), then
   **Received** (→ `Received`), or **Cancelled** (→ `Cancelled`).
2. Status transitions: `Draft → Submitted → Received`; `Draft/Submitted → Cancelled`.
3. A PO has one or more `PurchaseOrderLine` items: ProductId, Quantity, UnitPrice.
4. TotalAmount = Σ(Quantity × UnitPrice) across all lines.
5. Creating a PO validates: supplier exists, warehouse exists, each line's product exists
   and is `ProductType.Product`, lines non-empty, quantities > 0, unit prices ≥ 0.
6. `Reference` (optional) for supplier PO number.
7. `ExpectedDate` (optional) for when goods are expected.
8. `Notes` (optional, ≤500).

### Goods Received (GRN)

1. When a PO is **Received**, stock movements are created for each line:
   - `StockMovementType.OpeningStock` with `Quantity = line.Quantity` at the PO's
     warehouse/location, referencing the PO.
2. Stock balances are increased accordingly.
3. The PO status moves to `Received` and `ReceivedAt` is timestamped.
4. Cannot receive a PO that is not in `Submitted` status.

### Supplier Bill

1. A supplier bill is created after (or during) goods receipt. It references a PO.
2. A bill has `Subtotal`, `TaxAmount`, `TotalAmount`, `AmountPaid`, `Status`.
3. Bill statuses: `Draft → Approved → Paid → Void`.
4. Only one bill per PO (unique constraint on `PoId`).
5. Bill amount should match PO total (soft validation — warning, not hard block).

### Supplier Payment

1. Payments are made against a bill (or directly against a PO if no bill yet).
2. Payment methods: `Cash | MobileMoney | BankTransfer | Other` (same pattern as SalePayment).
3. `AmountPaid` on the bill is updated as payments accumulate.
4. When `AmountPaid >= TotalAmount`, bill status auto-transitions to `Paid`.

## Migration

- `Suppliers` table
- `PurchaseOrders` table + `PurchaseOrderLines` table
- `SupplierBills` table + `SupplierBillLines` table (optional: lines optional for Phase 1)
- `SupplierPayments` table

All with `TenantId`, audit columns, FK indexes, unique constraints as described above.
