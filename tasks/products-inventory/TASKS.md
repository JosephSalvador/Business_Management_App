# TASKS — Product & Inventory Foundation (Slice 3)

> Spec: `specs/products-inventory.md`. Implement one task at a time; run analyzers and tests
> after each; update this file as you go. No code until the spec is approved.
>
> Sub-slices: **3a Product Catalog** → **3b Inventory Foundation** → **3c Pricing Engine** →
> **3d Docs & verification**. Commit per approved task (commit style `feat(catalog): ...`,
> `feat(inventory): ...`, `feat(pricing): ...`, `docs(catalog): ...`).

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 3a — Product Catalog

- [x] 001 **Domain**: `UnitOfMeasure`, `ProductCategory` (optional parent, cycle guard),
      `Brand` aggregates; `Product` + `ProductVariant` child (sku/barcode rules, type/status
      enums, variants replace); domain events (`ProductCreatedEvent`,
      `ProductUpdatedEvent`, `ProductStatusChangedEvent`, `ProductVariantsChangedEvent`);
      new `PermissionNames`: `Products.View/Create/Update/Delete`, `Categories.View/Manage`,
      `Brands.View/Manage`, `Units.View/Manage`.
- [x] 002 **Persistence**: `ProductCategories`, `Brands`, `UnitsOfMeasure`, `Products`,
      `ProductVariants` DbSets + mappings (partial unique on tenant+sku/barcode); EF migration
      `20260813_AddProductInventoryAndPricing` (catalog tables only).
- [x] 003 **Ports + repositories**: `IProductRepository` (tenant-scoped
      `GetByIdAsync`, `ListAsync(page,pageSize,search,filter)`, `GetBySkuAsync`,
      `GetByBarcodeAsync`, `CountAsync`), `ICatalogRepository`-style ports for
      categories/brands/uoms (`ListAsync`, `GetByIdAsync`, `GetByNameAsync`, `AddAsync`,
      `RemoveAsync`); register in `Infrastructure/DependencyInjection`.
- [x] 004 **Application — products**: `Features/Products` commands/queries
      (`ListProductsQuery`, `GetProductQuery`, `CreateProductCommand`, `UpdateProductCommand`,
      `SetProductStatusCommand`, `DeleteProductCommand`, `SetProductVariantsCommand`,
      `GetProductVariantsQuery`) + DTOs/mappers/validators.
- [x] 005 **Application — catalog reference**: `Features/Catalog` commands/queries for
      categories/brands/units (`List/Create/Update/Get`, category cycle validation).
- [x] 006 **API endpoints**: `CatalogEndpoints` (products group) + `ReferenceDataEndpoints`
      (categories/brands/units groups) with `RequirePermission(Products.* / Categories.* /
      Brands.* / Units.*)`; register in `Program.cs`.
- [ ] 007 **Event consumers**: `CatalogActivityFeedHandler` in Notifications; register in
      `NotificationEngineExtensions`.
- [ ] 008 **Tests**: unit (product invariants, category cycle guard) + integration (CRUD,
      duplicate sku → Conflict, variant round-trip, status, 403, tenant isolation, audit rows,
      outbox dispatch).
- [ ] 009 **Docs + commit**: `dotnet build --warnaserror`, `dotnet format`, full test run;
      changelog bullet, `memory/project.md`; tick 3a tasks; completion report.

## 3b — Inventory Foundation

- [ ] 010 **Domain**: `Warehouse` + `StockLocation` child (default location on create, code
      normalization); `StockBalance` + `StockMovement` (immutable ledger, movement types,
      no-negative-balance invariant, transfer source≠destination); events
      (`OpeningStockRecordedEvent`, `StockAdjustedEvent`, `StockTransferredEvent`);
      `PermissionNames`: `Warehouses.View/Create/Update/Delete` (stock reuses existing
      `Inventory.View/Manage`).
- [ ] 011 **Persistence**: `Warehouses`, `StockLocations`, `StockBalances`, `StockMovements`
      DbSets + mappings (functional unique index on balance with `COALESCE(VariantId)`, ledger
      index); migration `20260813_AddProductInventoryAndPricing` (inventory tables).
- [ ] 012 **Ports + repositories**: `IWarehouseRepository` (tenant-scoped CRUD +
      `ListByIdsAsync`), `IStockRepository` (`GetBalanceWithLockAsync` using `FOR UPDATE`,
      `GetOrCreateBalanceAsync`, `AddMovementAsync`, `ListBalancesAsync`, `ListMovementsAsync`).
- [ ] 013 **Application — stock**: `Features/Inventory` commands/queries
      (`ListWarehousesQuery`, `GetWarehouseQuery`, `CreateWarehouseCommand`,
      `UpdateWarehouseCommand`, `SetWarehouseStatusCommand`, `DeleteWarehouseCommand`,
      `RecordOpeningStockCommand`, `AdjustStockCommand`, `TransferStockCommand`,
      `ListStockBalancesQuery`, `ListStockMovementsQuery`) + validators; row-lock serialization
      of concurrent movements on the same unit+location.
- [ ] 014 **API endpoints**: `InventoryEndpoints` (warehouses group + stock group) with
      `RequirePermission(Warehouses.* / Inventory.View / Inventory.Manage)`.
- [ ] 015 **Event consumers**: `InventoryActivityFeedHandler` in Notifications; register.
- [ ] 016 **Tests**: unit (ledger math: opening/adjust/transfer, no-negative, transfer rules)
      + integration (warehouse CRUD, opening→balance, adjustment, transfer updates both
      balances, negative → Conflict, tenant isolation, 403, audit rows, outbox dispatch).
- [ ] 017 **Docs + commit**: build/format/tests; changelog, memory; tick 3b; completion report.

## 3c — Pricing Engine

- [ ] 018 **Domain**: `PriceList` (default per tenant) + `ProductPrice` (branch override,
      price type, min-quantity, effective window); price-resolution pure function;
      events (`PriceListCreatedEvent`, `PriceListUpdatedEvent`,
      `ProductPricesChangedEvent`); `PermissionNames`: `Pricing.View/Manage`.
- [ ] 019 **Persistence**: `PriceLists`, `ProductPrices` DbSets + mappings (unique price key);
      migration `20260813_AddProductInventoryAndPricing` (pricing tables).
- [ ] 020 **Ports + repositories**: `IPriceListRepository` (tenant-scoped CRUD,
      `GetDefaultAsync`, `ResolvePricesAsync`), `IProductPriceRepository`
      (`ListAsync`, `UpsertManyAsync`, `ResolveAsync`).
- [ ] 021 **Application — pricing**: `Features/Pricing` commands/queries (`ListPriceListsQuery`,
      `GetPriceListQuery`, `CreatePriceListCommand`, `UpdatePriceListCommand`,
      `SetProductPricesCommand` bulk upsert, `GetPriceListPricesQuery`, `ResolvePriceQuery`)
      + `PriceResolver` (pure, unit-testable).
- [ ] 022 **API endpoints**: `PricingEndpoints` (price lists group + resolve) with
      `RequirePermission(Pricing.View / Pricing.Manage)`.
- [ ] 023 **Event consumers**: `PricingActivityFeedHandler` in Notifications; register.
- [ ] 024 **Tests**: unit (resolver: branch override, price type, min-quantity, effective
      dates, tie-break, no-price) + integration (price list CRUD, bulk upsert round-trip,
      default per tenant, resolve endpoint, 403, tenant isolation, audit rows, outbox).
- [ ] 025 **Docs + commit**: build/format/tests; changelog, memory; tick 3c; completion report.

## 3d — Docs & verification

- [ ] 026 **Docs + final verification**: `docs/roadmap.md` (item 4 `[x] backend slice`),
      changelog v0.5.0, `memory/project.md`, readiness report, spec status note; final
      `dotnet build --warnaserror`, `dotnet format`, full test run; Slice 3 release checkpoint.
