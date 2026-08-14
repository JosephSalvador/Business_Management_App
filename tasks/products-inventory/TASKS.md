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
- [x] 007 **Event consumers**: `CatalogActivityFeedHandler` in Notifications; register in
      `NotificationEngineExtensions`.
- [x] 008 **Tests**: unit (product invariants, category cycle guard) + integration (CRUD,
      duplicate sku → Conflict, variant round-trip, status, 403, tenant isolation, audit rows,
      outbox dispatch).
- [x] 009 **Docs + commit**: `dotnet build --warnaserror`, `dotnet format`, full test run;
      changelog bullet, `memory/project.md`; tick 3a tasks; completion report.

## 3b — Inventory Foundation

Scope: `Tenant → Branch → Warehouse → StockLocation` + immutable `StockMovement` ledger +
opening-stock recording. Adjustments, transfers, reservations, purchases and sales are
**out of scope** (their planned endpoints stay "deferred" in the spec).

- [x] 010 **3a errata — cross-table SKU/barcode uniqueness**: `CreateProductCommand` /
      `UpdateProductCommand` also reject a sku/barcode already used by a variant
      (`VariantSkuExistsAsync`/`VariantBarcodeExistsAsync`); `SetProductVariantsCommand` also
      rejects a sku/barcode already used by a product (`GetBySkuAsync`/`GetByBarcodeAsync`);
      integration test proving the product-sku-vs-variant-sku collision → `Conflict`. Per-table
      DB indexes + per-tenant advisory lock stay as is.
- [x] 011 **Domain — Warehouse + StockLocation**: `Warehouse` aggregate (Create with default
      location, UpdateProfile, Activate/Deactivate, code normalization uppercase, soft delete =
      deactivate) + `StockLocation` child (warehouse-scoped unique code, `Assign`/`Rename`);
      events (`WarehouseCreatedEvent`, `WarehouseUpdatedEvent`, `WarehouseStatusChangedEvent`);
      `PermissionNames`: `Warehouses.View/Create/Update/Delete`.
- [x] 012 **Domain — Stock ledger**: `StockBalance` (key
      `TenantId+WarehouseId+LocationId+ProductId+VariantId?`, running quantity) + `StockMovement`
      (immutable ledger row: signed quantityDelta, `MovementType` = `OpeningStock` for 3b,
      nullable `ReferenceType/ReferenceId`, `EffectiveAt`); `RecordOpeningStock` invariants
      (first movement on that key only, quantity > 0, sellable-unit key consistency, no
      negative); events (`OpeningStockRecordedEvent`, `StockMovementRecordedEvent`).
- [x] 013 **Persistence**: `Warehouses`, `StockLocations`, `StockBalances`, `StockMovements`
      DbSets + mappings (`Warehouses` unique `(TenantId, Code)` + `BranchId` Restrict FK;
      `StockLocations` unique `(WarehouseId, Code)`; `StockBalances` functional unique
      `(TenantId, WarehouseId, StockLocationId, ProductId, COALESCE(VariantId))`; ledger index
      `(TenantId, ProductId, CreatedAt)`; Restrict FKs to product/variant/location); migration
      `AddInventoryWarehousesAndStock`.
- [x] 014 **Ports + repositories**: `IWarehouseRepository` (tenant-scoped `GetByIdAsync` with
      locations, `GetByCodeAsync`, `ListAsync(page,pageSize,search,branchId)`, `CountAsync`,
      `AddAsync`) + `IStockRepository` (`GetOrCreateBalanceAsync`, `GetBalanceWithLockAsync`
      using `FOR UPDATE`, `AddMovementAsync`, `ListBalancesAsync`, `ListMovementsAsync`);
      register in DI.
- [x] 015 **Application — warehouses**: `Features/Inventory` warehouse commands/queries
      (List/Get/Create/Update/SetStatus/Delete + `SetStockLocationsCommand` replace-all) +
      validators; advisory lock on mutations.
- [x] 016 **Application — stock (opening)**: `RecordOpeningStockCommand` (row-lock
      serialization), `ListStockBalancesQuery`, `ListStockMovementsQuery` + validators.
- [x] 017 **API endpoints**: `InventoryEndpoints` (warehouses group + `/inventory/stock`,
      `/inventory/movements`, `/inventory/stock/opening`) with
      `RequirePermission(Warehouses.* / Inventory.View / Inventory.Manage)`; register.
- [x] 018 **Event consumers**: `InventoryActivityFeedHandler` in Notifications (warehouse +
      opening-stock events); register.
- [x] 019 **Tests**: unit (warehouse code normalization + default location + deactivate; ledger
      opening math, first-movement-only, no-negative, sellable-unit key) + integration
      (warehouse CRUD + status + locations, opening → balance + movement visible, duplicate code
      → Conflict, duplicate opening → Conflict, tenant isolation, 403, audit rows, outbox
      dispatch).
- [x] 020 **Docs + commit**: build/format/tests; changelog, memory; tick 3b; completion report;
      pause for review.

## 3c — Pricing Engine

- [ ] 021 **Domain**: `PriceList` (default per tenant) + `ProductPrice` (branch override,
      price type, min-quantity, effective window); price-resolution pure function;
      events (`PriceListCreatedEvent`, `PriceListUpdatedEvent`,
      `ProductPricesChangedEvent`); `PermissionNames`: `Pricing.View/Manage`.
- [ ] 022 **Persistence**: `PriceLists`, `ProductPrices` DbSets + mappings (unique price key);
      migration `AddPricingPriceLists`.
- [ ] 023 **Ports + repositories**: `IPriceListRepository` (tenant-scoped CRUD,
      `GetDefaultAsync`, `ResolvePricesAsync`), `IProductPriceRepository`
      (`ListAsync`, `UpsertManyAsync`, `ResolveAsync`).
- [ ] 024 **Application — pricing**: `Features/Pricing` commands/queries (`ListPriceListsQuery`,
      `GetPriceListQuery`, `CreatePriceListCommand`, `UpdatePriceListCommand`,
      `SetProductPricesCommand` bulk upsert, `GetPriceListPricesQuery`, `ResolvePriceQuery`)
      + `PriceResolver` (pure, unit-testable).
- [ ] 025 **API endpoints**: `PricingEndpoints` (price lists group + resolve) with
      `RequirePermission(Pricing.View / Pricing.Manage)`.
- [ ] 026 **Event consumers**: `PricingActivityFeedHandler` in Notifications; register.
- [ ] 027 **Tests**: unit (resolver: branch override, price type, min-quantity, effective
      dates, tie-break, no-price) + integration (price list CRUD, bulk upsert round-trip,
      default per tenant, resolve endpoint, 403, tenant isolation, audit rows, outbox).
- [ ] 028 **Docs + commit**: build/format/tests; changelog, memory; tick 3c; completion report.

## 3d — Docs & verification

- [ ] 029 **Docs + final verification**: `docs/roadmap.md` (item 4 `[x] backend slice`),
      changelog v0.5.0, `memory/project.md`, readiness report, spec status note; final
      `dotnet build --warnaserror`, `dotnet format`, full test run; Slice 3 release checkpoint.
