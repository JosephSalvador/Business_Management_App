# TASKS — Purchasing (Slice 8)

> Spec: `specs/purchasing.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: 8a Suppliers + PO Domain → 8b PO Commands + Endpoints → 8c Bills + Payments
> → 8d Tests + docs + commit. Commit style: `feat(purchasing): ...`, `test(purchasing): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 8a — Suppliers + PO Domain

- [x] 001 **Permissions**: Add `PurchasingView`, `PurchasingManage` to `PermissionNames`.
- [x] 002 **Domain — Supplier**: `Supplier` entity with factory invariants. Unit tests.
- [x] 003 **Domain — PurchaseOrder aggregate**: `PurchaseOrderStatus` enum, `PurchaseOrder` aggregate
       root with `PurchaseOrderLine` child entities. Factory with invariants. Status transitions.
       Unit tests.
- [x] 004 **Domain — SupplierBill**: `SupplierBillStatus` enum, `SupplierBill` aggregate root.
       Factory with invariants. Status transitions. Unit tests.
- [x] 005 **Domain — SupplierPayment**: `SupplierPayment` entity (child of SupplierBill). Factory
       with invariants (amount > 0). Unit tests.
- [x] 006 **Domain events**: `PurchaseOrderCreatedEvent`, `PurchaseOrderReceivedEvent`,
       `SupplierBillCreatedEvent`, `SupplierBillPaidEvent` records. Unit tests.

## 8b — PO Commands + Endpoints

- [x] 007 **Infrastructure — migration**: `AddPurchasing` migration (Suppliers, PurchaseOrders,
       PurchaseOrderLines, SupplierBills, SupplierPayments tables + FKs + indexes).
- [x] 008 **Infrastructure — repositories**: `ISupplierRepository`, `IPurchaseOrderRepository`,
       `ISupplierBillRepository`, `ISupplierPaymentRepository` ports + EF implementations +
       DI registration.
- [x] 009 **Application — create supplier**: `CreateSupplierCommand` + handler + validator.
       Unit tests.
- [x] 010 **Application — list/get suppliers**: `ListSuppliersQuery`, `GetSupplierQuery`,
       `UpdateSupplierCommand`.
- [x] 011 **Application — create PO**: `CreatePurchaseOrderCommand` + handler + validator.
       Unit tests.
- [x] 012 **Application — submit PO**: `SubmitPurchaseOrderCommand` + handler. Unit tests.
- [x] 013 **Application — receive PO**: `ReceivePurchaseOrderCommand` + handler (writes
       OpeningStock movements, updates balances). Unit tests.
- [x] 014 **Application — cancel PO**: `CancelPurchaseOrderCommand` + handler. Unit tests.
- [x] 015 **API — suppliers**: `POST /`, `GET /`, `GET /{id}`, `PUT /{id}`.
- [x] 016 **API — purchase orders**: `POST /`, `GET /`, `GET /{id}`, `POST /{id}/submit`,
       `POST /{id}/receive`, `POST /{id}/cancel`.

## 8c — Supplier Bills + Payments

- [x] 017 **Application — create bill**: `CreateSupplierBillCommand` + handler + validator.
       Unit tests.
- [x] 018 **Application — approve bill**: `ApproveSupplierBillCommand` + handler. Unit tests.
- [x] 019 **Application — void bill**: `VoidSupplierBillCommand` + handler. Unit tests.
- [x] 020 **Application — create payment**: `CreateSupplierPaymentCommand` + handler + validator.
       Unit tests.
- [x] 021 **API — bills**: `POST /`, `GET /`, `GET /{id}`, `POST /{id}/approve`,
       `POST /{id}/void`.
- [x] 022 **API — payments**: `POST /{id}/payments`.

## 8d — Tests + docs + commit

- [!] 023 **Full integration suite**: Blocked — Postgres not available for integration tests.
       Unit tests (63) all pass.
- [!] 024 **Docs + commit**: Blocked — depends on task 023.
