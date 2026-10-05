# Dependency & Import Map — JOLINX Business OS

> Auto-generated on 2026-08-31.  
> Source: 96 non-generated `.dart` files in `lib/`.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| `pkg` | Package import (`package:...`) |
| `dart` | Dart SDK import (`dart:...`) |
| `rel` | Relative import (project-internal) |
| `part` | Part directive (generated code) |
| `export` | Re-export of another file |
| `conditional` | Conditional export / import |

---

## 1. Entry Point

### `lib/main.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_dotenv/flutter_dotenv.dart` |
| pkg | `package:flutter_localizations/flutter_localizations.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `core/routing/app_router.dart` |
| rel | `core/config/app_config.dart` |
| rel | `core/di/providers.dart` |
| rel | `core/local/db_key_store.dart` |
| rel | `core/local/local_database.dart` |
| rel | `core/local/locale_store.dart` |
| rel | `core/theme/app_theme.dart` |
| rel | `l10n/generated/app_localizations.dart` |

---

## 2. Core

### `lib/core/config/app_config.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_dotenv/flutter_dotenv.dart` |

### `lib/core/di/providers.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../config/app_config.dart` |
| rel | `../local/db_key_store.dart` |
| rel | `../local/device_identity.dart` |
| rel | `../local/local_database.dart` |
| rel | `../local/session_journal.dart` |
| rel | `../../features/auth/application/auth_controller.dart` |
| rel | `../../features/auth/data/auth_repository.dart` |
| rel | `../../features/auth/data/secure_token_store.dart` |
| rel | `../../features/products/application/catalog_controller.dart` |
| rel | `../../features/products/application/products_controller.dart` |
| rel | `../../features/products/application/stock_controller.dart` |
| rel | `../../features/products/data/product_repository.dart` |
| rel | `../../features/sales/application/cart_controller.dart` |
| rel | `../../features/sales/application/checkout_controller.dart` |
| rel | `../../features/sales/application/local_sales_service.dart` |
| rel | `../../features/sales/application/offline_sale_recorder.dart` |
| rel | `../../features/sales/application/pos_catalog_controller.dart` |
| rel | `../../features/sales/application/sales_history_controller.dart` |
| rel | `../../features/sales/application/sync_engine.dart` |
| rel | `../../features/sales/data/sale_repository.dart` |
| rel | `../../features/workspace/application/workspace_controller.dart` |
| rel | `../../features/workspace/data/workspace_repository.dart` |
| rel | `../network/api_client.dart` |
| rel | `../network/api_routes.dart` |
| rel | `../network/connectivity_monitor.dart` |

> **NOTE:** Highest fan-out file (28 imports). Central DI composition root.

### `lib/core/routing/app_router.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/foundation.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../features/auth/application/auth_controller.dart` |
| rel | `../../features/workspace/application/workspace_controller.dart` |
| rel | `../../features/auth/presentation/pages/forgot_password_page.dart` |
| rel | `../../features/auth/presentation/pages/home_page.dart` |
| rel | `../../features/auth/presentation/pages/login_page.dart` |
| rel | `../../features/auth/presentation/pages/register_page.dart` |
| rel | `../../features/auth/presentation/pages/reset_password_page.dart` |
| rel | `../../features/auth/presentation/pages/staff_page.dart` |
| rel | `../../features/auth/presentation/pages/terms_page.dart` |
| rel | `../../features/customers/presentation/pages/customer_detail_page.dart` |
| rel | `../../features/customers/presentation/pages/customer_form_page.dart` |
| rel | `../../features/customers/presentation/pages/customers_page.dart` |
| rel | `../../features/expenses/presentation/pages/expense_form_page.dart` |
| rel | `../../features/expenses/presentation/pages/expenses_page.dart` |
| rel | `../../features/products/presentation/pages/product_detail_page.dart` |
| rel | `../../features/products/presentation/pages/product_form_page.dart` |
| rel | `../../features/profile/presentation/pages/profile_page.dart` |
| rel | `../../features/purchases/presentation/pages/purchase_detail_page.dart` |
| rel | `../../features/purchases/presentation/pages/purchase_form_page.dart` |
| rel | `../../features/purchases/presentation/pages/purchases_page.dart` |
| rel | `../../features/reports/presentation/pages/reports_page.dart` |
| rel | `../../features/sales/domain/sale.dart` |
| rel | `../../features/sales/presentation/pages/pos_page.dart` |
| rel | `../../features/sales/presentation/pages/receipt_preview_page.dart` |
| rel | `../../features/sales/presentation/pages/sale_detail_page.dart` |
| rel | `../../features/sales/presentation/pages/sale_success_page.dart` |
| rel | `../../features/sales/presentation/pages/sales_history_page.dart` |
| rel | `../../features/settings/presentation/pages/settings_page.dart` |
| rel | `../../features/suppliers/presentation/pages/supplier_form_page.dart` |
| rel | `../../features/suppliers/presentation/pages/suppliers_page.dart` |
| rel | `../../features/users/presentation/pages/role_form_page.dart` |
| rel | `../../features/users/presentation/pages/roles_page.dart` |
| rel | `../../features/users/presentation/pages/user_form_page.dart` |
| rel | `../../features/users/presentation/pages/users_page.dart` |
| rel | `../../features/workspace/presentation/pages/business_setup_page.dart` |
| rel | `../../features/workspace/presentation/pages/create_business_page.dart` |
| rel | `../../features/workspace/presentation/pages/splash_page.dart` |
| rel | `../../features/workspace/presentation/pages/verify_email_page.dart` |
| rel | `../../features/workspace/presentation/pages/workspace_picker_page.dart` |
| rel | `../../features/workspace/presentation/pages/zero_workspace_page.dart` |
| rel | `../../shared/widgets/not_found_page.dart` |
| rel | `../di/providers.dart` |

> **NOTE:** Second-highest fan-out (44 imports). Central routing hub.

### `lib/core/theme/app_theme.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/core/utils/responsive.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/core/widgets/responsive_layout.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| rel | `../utils/responsive.dart` |

---

## 3. Core — Network

### `lib/core/network/api_client.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:dio/dio.dart` |
| pkg | `package:flutter/foundation.dart` |
| rel | `../config/app_config.dart` |
| rel | `app_exception.dart` |
| rel | `error_mapper.dart` |

### `lib/core/network/api_routes.dart`
*(No imports — pure constants file)*

### `lib/core/network/app_exception.dart`
*(No imports — sealed class hierarchy)*

### `lib/core/network/error_mapper.dart`
| Type | Import |
|------|--------|
| pkg | `package:dio/dio.dart` |
| rel | `app_exception.dart` |

### `lib/core/network/connectivity_monitor.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:connectivity_plus/connectivity_plus.dart` |
| pkg | `package:dio/dio.dart` *(show Options, DioException)* |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../di/providers.dart` |
| rel | `api_client.dart` |
| rel | `api_routes.dart` |
| rel | `app_exception.dart` |

---

## 4. Core — Local (Drift DB / Storage)

### `lib/core/local/local_database.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` |
| rel | `db_executor.dart` |
| rel | `tables.dart` |
| part | `local_database.g.dart` |

### `lib/core/local/tables.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` |

### `lib/core/local/db_executor.dart`
| Type | Import |
|------|--------|
| export | `db_executor_native.dart` *(conditional: `dart.library.io`)* |
| export | `db_executor_web.dart` *(conditional: `dart.library.js_interop`)* |

### `lib/core/local/db_executor_native.dart`
| Type | Import |
|------|--------|
| dart | `dart:io` |
| pkg | `package:drift/drift.dart` |
| pkg | `package:drift/native.dart` |
| pkg | `package:flutter/foundation.dart` |
| pkg | `package:path/path.dart` *(as p)* |
| pkg | `package:path_provider/path_provider.dart` |
| pkg | `package:sqlite3/sqlite3.dart` *(show Database)* |

### `lib/core/local/db_executor_web.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` |
| pkg | `package:drift/wasm.dart` |
| pkg | `package:flutter/foundation.dart` |

### `lib/core/local/cached_catalog_dao.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` |
| rel | `local_database.dart` |
| rel | `tables.dart` |
| export | `tables.dart` *(show LocalSaleStatus, LocalProductCodes)* |

### `lib/core/local/local_sales_dao.dart`
| Type | Import |
|------|--------|
| dart | `dart:convert` |
| pkg | `package:drift/drift.dart` |
| pkg | `package:uuid/uuid.dart` |
| rel | `local_database.dart` |
| rel | `tables.dart` |
| export | `tables.dart` *(show SyncOperationStatus, LocalSaleStatus)* |

### `lib/core/local/sync_queue_dao.dart`
| Type | Import |
|------|--------|
| dart | `dart:convert` |
| pkg | `package:drift/drift.dart` |
| rel | `local_database.dart` |
| rel | `tables.dart` |
| export | `tables.dart` *(show SyncOperationStatus)* |

### `lib/core/local/session_journal.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` *(show Value)* |
| rel | `local_database.dart` |

### `lib/core/local/device_identity.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_secure_storage/flutter_secure_storage.dart` |
| pkg | `package:uuid/uuid.dart` |

### `lib/core/local/db_key_store.dart`
| Type | Import |
|------|--------|
| dart | `dart:convert` |
| dart | `dart:math` |
| pkg | `package:flutter_secure_storage/flutter_secure_storage.dart` |

### `lib/core/local/locale_store.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/widgets.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:flutter_secure_storage/flutter_secure_storage.dart` |

---

## 5. Features — Auth

### `lib/features/auth/domain/session.dart`
*(No imports — pure model)*

### `lib/features/auth/data/auth_repository.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:dio/dio.dart` |
| rel | `../../../core/network/api_client.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../domain/session.dart` |

### `lib/features/auth/data/secure_token_store.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_secure_storage/flutter_secure_storage.dart` |
| rel | `../../../core/network/api_client.dart` |

### `lib/features/auth/application/auth_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/auth_repository.dart` |
| rel | `../domain/session.dart` |

### `lib/features/auth/presentation/pages/login_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../widgets/auth_brand_mark.dart` |
| rel | `../widgets/auth_error_mapper.dart` |
| rel | `../widgets/language_switcher.dart` |
| rel | `../widgets/password_field.dart` |

### `lib/features/auth/presentation/pages/register_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../widgets/auth_error_mapper.dart` |
| rel | `../widgets/language_switcher.dart` |
| rel | `../widgets/password_field.dart` |

### `lib/features/auth/presentation/pages/forgot_password_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../widgets/language_switcher.dart` |

### `lib/features/auth/presentation/pages/reset_password_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../widgets/password_field.dart` |

### `lib/features/auth/presentation/pages/home_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../../../dashboard/presentation/pages/dashboard_page.dart` |
| rel | `../../../products/presentation/pages/products_page.dart` |
| rel | `../../../reports/presentation/pages/reports_page.dart` |
| rel | `../../../sales/presentation/pages/pos_page.dart` |
| rel | `../../../workspace/application/workspace_controller.dart` |
| rel | `../../application/auth_controller.dart` |

### `lib/features/auth/presentation/pages/staff_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter/services.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:intl/intl.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../../l10n/loc.dart` |
| rel | `../widgets/auth_error_mapper.dart` |

### `lib/features/auth/presentation/pages/terms_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| rel | `../../../../l10n/loc.dart` |

### `lib/features/auth/presentation/widgets/auth_brand_mark.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/features/auth/presentation/widgets/auth_error_mapper.dart`
| Type | Import |
|------|--------|
| rel | `../../../../core/network/app_exception.dart` |

### `lib/features/auth/presentation/widgets/language_switcher.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/local/locale_store.dart` |
| rel | `../../../../l10n/loc.dart` |

### `lib/features/auth/presentation/widgets/password_field.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| rel | `../../../../l10n/loc.dart` |

---

## 6. Features — Workspace

### `lib/features/workspace/domain/workspace.dart`
*(No imports — pure model)*

### `lib/features/workspace/data/workspace_repository.dart`
| Type | Import |
|------|--------|
| rel | `../../../core/network/api_client.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../domain/workspace.dart` |

### `lib/features/workspace/application/workspace_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/workspace_repository.dart` |
| rel | `../domain/workspace.dart` |

### `lib/features/workspace/presentation/pages/splash_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../application/workspace_controller.dart` |

### `lib/features/workspace/presentation/pages/verify_email_page.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../../auth/application/auth_controller.dart` |

### `lib/features/workspace/presentation/pages/workspace_picker_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../application/workspace_controller.dart` |
| rel | `../../domain/workspace.dart` |

### `lib/features/workspace/presentation/pages/zero_workspace_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/routing/app_router.dart` |

### `lib/features/workspace/presentation/pages/create_business_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../data/workspace_repository.dart` |

### `lib/features/workspace/presentation/pages/business_setup_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../products/application/catalog_controller.dart` |
| rel | `../../../workspace/application/workspace_controller.dart` |

---

## 7. Features — Products

### `lib/features/products/domain/product.dart`
*(No imports — pure model)*

### `lib/features/products/domain/catalog.dart`
*(No imports — pure model)*

### `lib/features/products/data/product_repository.dart`
| Type | Import |
|------|--------|
| pkg | `package:dio/dio.dart` |
| rel | `../../../core/network/api_client.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../domain/catalog.dart` |
| rel | `../domain/product.dart` |

### `lib/features/products/application/catalog_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/product_repository.dart` |
| rel | `../domain/catalog.dart` |

### `lib/features/products/application/products_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/product_repository.dart` |
| rel | `../domain/catalog.dart` |
| rel | `../domain/product.dart` |

### `lib/features/products/application/stock_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/product_repository.dart` |
| rel | `../domain/product.dart` |

### `lib/features/products/presentation/pages/products_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../application/products_controller.dart` |
| rel | `../../domain/product.dart` |
| rel | `opening_stock_sheet.dart` |

### `lib/features/products/presentation/pages/product_detail_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/format/money.dart` |

### `lib/features/products/presentation/pages/product_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../workspace/application/workspace_controller.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../application/catalog_controller.dart` |
| rel | `../../data/product_repository.dart` |
| rel | `../../domain/product.dart` |

### `lib/features/products/presentation/pages/stock_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../application/stock_controller.dart` |

### `lib/features/products/presentation/pages/opening_stock_sheet.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/app_exception.dart` |
| rel | `../../application/catalog_controller.dart` |
| rel | `../../data/product_repository.dart` |
| rel | `../../domain/product.dart` |

---

## 8. Features — Sales

### `lib/features/sales/domain/sale.dart`
*(No imports — pure model + functions)*

### `lib/features/sales/domain/receipt.dart`
| Type | Import |
|------|--------|
| rel | `../../../shared/format/money.dart` |
| rel | `sale.dart` |

### `lib/features/sales/data/sale_repository.dart`
| Type | Import |
|------|--------|
| rel | `../../../core/network/api_client.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../domain/sale.dart` |

### `lib/features/sales/application/cart_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../domain/sale.dart` |

### `lib/features/sales/application/checkout_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:uuid/uuid.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/sale_repository.dart` |
| rel | `../domain/sale.dart` |
| rel | `offline_sale_recorder.dart` |

### `lib/features/sales/application/offline_sale_recorder.dart`
| Type | Import |
|------|--------|
| rel | `../../../core/local/cached_catalog_dao.dart` |
| rel | `../../../core/local/local_sales_dao.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../domain/sale.dart` |

### `lib/features/sales/application/local_sales_service.dart`
| Type | Import |
|------|--------|
| rel | `../../../core/local/cached_catalog_dao.dart` |
| rel | `../domain/sale.dart` |
| rel | `../../../core/local/local_database.dart` *(show LocalDatabase)* |
| rel | `../../../core/local/local_sales_dao.dart` |
| rel | `../../../core/local/sync_queue_dao.dart` |

### `lib/features/sales/application/pos_catalog_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:drift/drift.dart` *(show Value)* |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/local/cached_catalog_dao.dart` |
| rel | `../../../core/local/local_database.dart` *(show companions)* |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../../products/data/product_repository.dart` |
| rel | `../../products/domain/product.dart` |

### `lib/features/sales/application/sales_history_controller.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../core/di/providers.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/sale_repository.dart` |
| rel | `../domain/sale.dart` |

### `lib/features/sales/application/sync_engine.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| dart | `dart:convert` |
| pkg | `package:flutter/foundation.dart` |
| rel | `../../../core/network/app_exception.dart` |
| rel | `../data/sale_repository.dart` |
| rel | `../../../core/local/sync_queue_dao.dart` *(show QueuedOperation)* |
| rel | `local_sales_service.dart` |

### `lib/features/sales/presentation/pages/pos_page.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter/services.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/connectivity_monitor.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../application/cart_controller.dart` |
| rel | `../../application/pos_catalog_controller.dart` |
| rel | `sync_status_sheet.dart` |
| rel | `payment_sheet.dart` |

### `lib/features/sales/presentation/pages/payment_sheet.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../application/checkout_controller.dart` |
| rel | `../../domain/sale.dart` |

### `lib/features/sales/presentation/pages/cart_sheet.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `payment_sheet.dart` |

### `lib/features/sales/presentation/pages/receipt_preview_page.dart`
| Type | Import |
|------|--------|
| dart | `dart:io` |
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter/services.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:path/path.dart` *(as p)* |
| pkg | `package:path_provider/path_provider.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../workspace/application/workspace_controller.dart` |
| rel | `../../domain/receipt.dart` |
| rel | `../../domain/sale.dart` |

### `lib/features/sales/presentation/pages/sale_detail_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../domain/sale.dart` |

### `lib/features/sales/presentation/pages/sales_history_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../application/sales_history_controller.dart` |
| rel | `../../domain/sale.dart` |

### `lib/features/sales/presentation/pages/sale_success_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/routing/app_router.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../domain/sale.dart` |

### `lib/features/sales/presentation/pages/sync_status_sheet.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/connectivity_monitor.dart` |

---

## 9. Features — Customers

### `lib/features/customers/presentation/pages/customers_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/widgets/app_search_bar.dart` |
| rel | `../../../../shared/widgets/empty_state.dart` |

### `lib/features/customers/presentation/pages/customer_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

### `lib/features/customers/presentation/pages/customer_detail_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

---

## 10. Features — Dashboard

### `lib/features/dashboard/presentation/pages/dashboard_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../../../shared/widgets/stat_card.dart` |
| rel | `../widgets/revenue_line_chart.dart` |

### `lib/features/dashboard/presentation/widgets/revenue_line_chart.dart`
| Type | Import |
|------|--------|
| pkg | `package:fl_chart/fl_chart.dart` |
| pkg | `package:flutter/material.dart` |
| pkg | `package:intl/intl.dart` |
| rel | `../../../../shared/format/money.dart` |

---

## 11. Features — Expenses

### `lib/features/expenses/presentation/pages/expenses_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| pkg | `package:intl/intl.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../../../shared/widgets/app_search_bar.dart` |
| rel | `../../../../shared/widgets/empty_state.dart` |

### `lib/features/expenses/presentation/pages/expense_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:go_router/go_router.dart` |

---

## 12. Features — Purchases

### `lib/features/purchases/presentation/pages/purchases_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| pkg | `package:intl/intl.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/format/money.dart` |
| rel | `../../../../shared/widgets/app_search_bar.dart` |
| rel | `../../../../shared/widgets/empty_state.dart` |

### `lib/features/purchases/presentation/pages/purchase_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

### `lib/features/purchases/presentation/pages/purchase_detail_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:intl/intl.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/format/money.dart` |

---

## 13. Features — Reports

### `lib/features/reports/presentation/pages/reports_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/format/money.dart` |

---

## 14. Features — Suppliers

### `lib/features/suppliers/presentation/pages/suppliers_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |
| rel | `../../../../shared/widgets/app_search_bar.dart` |
| rel | `../../../../shared/widgets/empty_state.dart` |

### `lib/features/suppliers/presentation/pages/supplier_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

---

## 15. Features — Users

### `lib/features/users/presentation/pages/users_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

### `lib/features/users/presentation/pages/user_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

### `lib/features/users/presentation/pages/roles_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

### `lib/features/users/presentation/pages/role_form_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

---

## 16. Features — Profile

### `lib/features/profile/presentation/pages/profile_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

---

## 17. Features — Settings

### `lib/features/settings/presentation/pages/settings_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |
| pkg | `package:flutter_riverpod/flutter_riverpod.dart` |
| pkg | `package:go_router/go_router.dart` |
| rel | `../../../../core/di/providers.dart` |
| rel | `../../../../core/network/api_routes.dart` |

---

## 18. Shared

### `lib/shared/format/money.dart`
| Type | Import |
|------|--------|
| pkg | `package:intl/intl.dart` |

### `lib/shared/widgets/stat_card.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/shared/widgets/section_header.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/shared/widgets/empty_state.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/shared/widgets/app_search_bar.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

### `lib/shared/widgets/not_found_page.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/material.dart` |

---

## 19. L10n (Localization)

### `lib/l10n/loc.dart`
| Type | Import |
|------|--------|
| pkg | `package:flutter/widgets.dart` |
| rel | `generated/app_localizations.dart` |

### `lib/l10n/generated/app_localizations.dart`
| Type | Import |
|------|--------|
| dart | `dart:async` |
| pkg | `package:flutter/foundation.dart` |
| pkg | `package:flutter/widgets.dart` |
| pkg | `package:flutter_localizations/flutter_localizations.dart` |
| pkg | `package:intl/intl.dart` *(as intl)* |
| rel | `app_localizations_en.dart` |
| rel | `app_localizations_sw.dart` |

### `lib/l10n/generated/app_localizations_en.dart`
| Type | Import |
|------|--------|
| pkg | `package:intl/intl.dart` *(as intl)* |
| rel | `app_localizations.dart` |

### `lib/l10n/generated/app_localizations_sw.dart`
| Type | Import |
|------|--------|
| pkg | `package:intl/intl.dart` *(as intl)* |
| rel | `app_localizations.dart` |

---

## 20. Third-Party Package Summary

| Package | Used By (count) |
|---------|-----------------|
| `flutter/material.dart` | 45+ files |
| `flutter_riverpod` | 30+ files |
| `go_router` | 25+ files |
| `drift` | 10 files (local DB layer) |
| `dio` | 4 files (network) |
| `flutter_secure_storage` | 4 files |
| `intl` | 6 files |
| `connectivity_plus` | 1 file |
| `fl_chart` | 1 file |
| `uuid` | 3 files |
| `path_provider` | 2 files |
| `path` | 2 files |
| `sqlite3` | 1 file (native) |
| `flutter_dotenv` | 2 files |
| `flutter_localizations` | 2 files |

---

## 21. Cross-Feature Dependency Graph

```
main.dart
  └── core/di/providers.dart  (composition root — 28 imports)
        ├── core/config/*
        ├── core/local/*
        ├── core/network/*
        ├── features/auth/*
        ├── features/products/*
        ├── features/sales/*
        └── features/workspace/*

core/routing/app_router.dart  (routing hub — 44 imports)
  ├── core/di/providers.dart
  ├── features/auth/presentation/pages/*
  ├── features/customers/presentation/pages/*
  ├── features/expenses/presentation/pages/*
  ├── features/products/presentation/pages/*
  ├── features/profile/presentation/pages/*
  ├── features/purchases/presentation/pages/*
  ├── features/reports/presentation/pages/*
  ├── features/sales/presentation/pages/*
  ├── features/settings/presentation/pages/*
  ├── features/suppliers/presentation/pages/*
  ├── features/users/presentation/pages/*
  └── features/workspace/presentation/pages/*
```

### Feature-Level Dependencies (who imports whom across features)

| Feature A | Imports from Feature B |
|-----------|----------------------|
| `auth/presentation/pages/home_page` | `dashboard`, `products`, `reports`, `sales`, `workspace` |
| `auth/presentation/pages/staff` | *(none — standalone)* |
| `sales/application/pos_catalog_controller` | `products/data/product_repository`, `products/domain/product` |
| `sales/presentation/pages/receipt_preview` | `workspace/application/workspace_controller` |
| `workspace/presentation/pages/business_setup` | `products/application/catalog_controller` |
| `workspace/presentation/pages/verify_email` | `auth/application/auth_controller` |
| `core/di/providers.dart` | `auth`, `products`, `sales`, `workspace` (all controllers/repos) |

### Feature-Internal Dependency Chains

**Auth:** `domain/session` <- `data/auth_repository` <- `application/auth_controller` <- `presentation/pages/*`

**Products:** `domain/{product,catalog}` <- `data/product_repository` <- `application/{catalog,products,stock}_controller` <- `presentation/pages/*`

**Sales:** `domain/sale` <- `data/sale_repository` <- `application/{checkout,cart,pos_catalog,sales_history,sync_engine,local_sales_service,offline_sale_recorder}_controller` <- `presentation/pages/*`

**Workspace:** `domain/workspace` <- `data/workspace_repository` <- `application/workspace_controller` <- `presentation/pages/*`

---

## 22. Files With Zero Dependencies (Leaf Nodes)

These files have no project-internal imports:

| File | Notes |
|------|-------|
| `core/network/api_routes.dart` | Pure API route constants |
| `core/network/app_exception.dart` | Sealed exception hierarchy |
| `features/auth/domain/session.dart` | Pure model |
| `features/products/domain/product.dart` | Pure model |
| `features/products/domain/catalog.dart` | Pure model |
| `features/sales/domain/sale.dart` | Pure model + functions |
| `features/workspace/domain/workspace.dart` | Pure model |
| `shared/format/money.dart` | Intl-only |
| `shared/widgets/stat_card.dart` | Flutter-only widget |
| `shared/widgets/section_header.dart` | Flutter-only widget |
| `shared/widgets/empty_state.dart` | Flutter-only widget |
| `shared/widgets/app_search_bar.dart` | Flutter-only widget |
| `shared/widgets/not_found_page.dart` | Flutter-only widget |
| `core/theme/app_theme.dart` | Flutter-only |
| `core/utils/responsive.dart` | Flutter-only |
| `features/auth/presentation/widgets/auth_brand_mark.dart` | Flutter-only widget |
| `features/expenses/presentation/pages/expense_form_page.dart` | Flutter + GoRouter only |
