# Full UI Implementation Plan — JOLINX Business OS

## Goal
Build ALL screens from the UI mockup as fully functional Flutter screens connected to real backend APIs.

## Current State
- **Backend:** ~95 API endpoints (Auth, Users, Roles, Products, Inventory, Sales, Pricing, Purchasing, Dashboard, Reports, Accounting)
- **Flutter:** 23 screens (Auth, POS, Products, Stock, Sales History)
- **Missing backend:** Customers, Expenses (need to build)
- **Missing Flutter:** 15+ screens

## Implementation Phases

### Phase 1: Backend — Missing Features
Build the missing backend features that the Flutter screens depend on.

| Task | Description | Est. |
|------|-------------|------|
| 1.1 | `Customer` domain entity + migration | Backend |
| 1.2 | `Customer` repository + application layer (CRUD) | Backend |
| 1.3 | `CustomerEndpoints` API | Backend |
| 1.4 | `Expense` domain entity + migration | Backend |
| 1.5 | `Expense` repository + application layer (CRUD) | Backend |
| 1.6 | `ExpenseEndpoints` API | Backend |

### Phase 2: Flutter — Core Infrastructure
Set up shared widgets and theme updates to match the mockup design system.

| Task | Description | Files |
|------|-------------|-------|
| 2.1 | Update `AppColors` to match mockup (add danger red, gray, update blue) | `app_theme.dart` |
| 2.2 | Create shared UI components (SearchBar, EmptyState, StatCard, ListTile variants) | `shared/widgets/` |
| 2.3 | Add new routes to `app_router.dart` | `app_router.dart` |

### Phase 3: Flutter — Dashboard (Screen #3)
| Task | Description | Files |
|------|-------------|-------|
| 3.1 | `DashboardRepository` + `DashboardController` | `features/dashboard/` |
| 3.2 | `DashboardPage` — KPIs (sales today, products, stock value, branches) | `features/dashboard/` |
| 3.3 | Low stock alerts section | `features/dashboard/` |
| 3.4 | Recent activity feed | `features/dashboard/` |

### Phase 4: Flutter — Product Detail (Screen #9)
| Task | Description | Files |
|------|-------------|-------|
| 4.1 | `ProductDetailPage` — image, info, price, stock levels | `features/products/` |
| 4.2 | Product detail route + navigation from products list | `app_router.dart` |

### Phase 5: Flutter — Customers (Screen #13)
| Task | Description | Files |
|------|-------------|-------|
| 5.1 | `CustomerRepository` + `CustomersController` | `features/customers/` |
| 5.2 | `CustomersPage` — searchable list | `features/customers/` |
| 5.3 | `CustomerFormPage` — add/edit | `features/customers/` |
| 5.4 | `CustomerDetailPage` — info + purchase history | `features/customers/` |

### Phase 6: Flutter — Suppliers (Screen #14)
| Task | Description | Files |
|------|-------------|-------|
| 6.1 | `SupplierRepository` + `SuppliersController` | `features/suppliers/` |
| 6.2 | `SuppliersPage` — searchable list | `features/suppliers/` |
| 6.3 | `SupplierFormPage` — add/edit | `features/suppliers/` |

### Phase 7: Flutter — Purchases (Screen #11)
| Task | Description | Files |
|------|-------------|-------|
| 7.1 | `PurchaseRepository` + `PurchasesController` | `features/purchases/` |
| 7.2 | `PurchasesPage` — purchase order list | `features/purchases/` |
| 7.3 | `PurchaseDetailPage` — order details + actions | `features/purchases/` |
| 7.4 | `PurchaseFormPage` — create purchase order | `features/purchases/` |

### Phase 8: Flutter — Expenses (Screen #12)
| Task | Description | Files |
|------|-------------|-------|
| 8.1 | `ExpensesRepository` + `ExpensesController` | `features/expenses/` |
| 8.2 | `ExpensesPage` — expense list | `features/expenses/` |
| 8.3 | `ExpenseFormPage` — add/edit expense | `features/expenses/` |

### Phase 9: Flutter — Reports (Screens #15, #16)
| Task | Description | Files |
|------|-------------|-------|
| 9.1 | `ReportsRepository` + `ReportsController` | `features/reports/` |
| 9.2 | `SalesReportPage` — date range, summary, chart | `features/reports/` |
| 9.3 | `TopProductsPage` — top selling products | `features/reports/` |
| 9.4 | Replace `_PlaceholderTab` in HomePage with ReportsPage | `home_page.dart` |

### Phase 10: Flutter — User Management (Screens #17, #18)
| Task | Description | Files |
|------|-------------|-------|
| 10.1 | `UsersRepository` + `UsersController` | `features/users/` |
| 10.2 | `UsersPage` — user list with roles | `features/users/` |
| 10.3 | `UserFormPage` — add/edit user | `features/users/` |
| 10.4 | `RolesPage` — role list + permission matrix | `features/users/` |
| 10.5 | `RoleFormPage` — edit role permissions | `features/users/` |

### Phase 11: Flutter — Settings (Screen #19)
| Task | Description | Files |
|------|-------------|-------|
| 11.1 | `SettingsPage` — business info, tax, notifications, language | `features/settings/` |
| 11.2 | Wire settings into the More tab (Zaidi) | `home_page.dart` |

### Phase 12: Flutter — Profile (Screen #21)
| Task | Description | Files |
|------|-------------|-------|
| 12.1 | `ProfilePage` — user info, edit profile | `features/profile/` |
| 12.2 | Wire profile into More tab or app bar | `home_page.dart` |

### Phase 13: Integration & Polish
| Task | Description |
|------|-------------|
| 13.1 | Update bottom nav to match mockup (5 tabs: Dashboard, Bidhaa, Mauzo, Ripoti, Zaidi) |
| 13.2 | Add navigation from More tab to all sub-screens |
| 13.3 | `flutter analyze` clean |
| 13.4 | Run all tests |
| 13.5 | Update AGENTS.md |

## Screen → Tab Mapping (Mockup)
| Tab | Label | Screen |
|-----|-------|--------|
| 0 | Dashboard | DashboardPage (NEW) |
| 1 | Bidhaa | ProductsPage (EXISTS) |
| 2 | Mauzo | PosPage (EXISTS) |
| 3 | Ripoti | ReportsPage (NEW - replaces placeholder) |
| 4 | Zaidi | MoreTab (EXISTS - enhanced with links) |

## Route Map
```
/                           → SplashPage (EXISTS)
/login                      → LoginPage (EXISTS)
/home                       → HomePage (EXISTS - updated tabs)
/home?tab=0                 → Dashboard
/home?tab=1                 → Products
/home?tab=2                 → POS
/home?tab=3                 → Reports
/home?tab=4                 → More
/products/:id               → ProductDetailPage (NEW)
/products/new               → ProductFormPage (EXISTS)
/customers                  → CustomersPage (NEW)
/customers/new              → CustomerFormPage (NEW)
/customers/:id              → CustomerDetailPage (NEW)
/customers/:id/edit         → CustomerFormPage (NEW)
/suppliers                  → SuppliersPage (NEW)
/suppliers/new              → SupplierFormPage (NEW)
/suppliers/:id/edit         → SupplierFormPage (NEW)
/purchases                  → PurchasesPage (NEW)
/purchases/new              → PurchaseFormPage (NEW)
/purchases/:id              → PurchaseDetailPage (NEW)
/expenses                   → ExpensesPage (NEW)
/expenses/new               → ExpenseFormPage (NEW)
/expenses/:id/edit          → ExpenseFormPage (NEW)
/reports/sales              → SalesReportPage (NEW)
/reports/top-products       → TopProductsPage (NEW)
/users                      → UsersPage (NEW)
/users/new                  → UserFormPage (NEW)
/users/:id/edit             → UserFormPage (NEW)
/roles                      → RolesPage (NEW)
/roles/new                  → RoleFormPage (NEW)
/roles/:id/edit             → RoleFormPage (NEW)
/settings                   → SettingsPage (NEW)
/profile                    → ProfilePage (NEW)
```

## Backend API Dependency Matrix
| Flutter Screen | Backend API | Status |
|----------------|-------------|--------|
| Dashboard | GET /dashboard/summary, /low-stock, /recent-activity | ✅ Exists |
| Product Detail | GET /products/{id} | ✅ Exists |
| Customers | GET/POST/PUT /customers | ❌ Need to build |
| Suppliers | GET/POST/PUT /suppliers | ✅ Exists |
| Purchases | GET/POST /purchase-orders | ✅ Exists |
| Expenses | GET/POST/PUT /expenses | ❌ Need to build |
| Sales Report | GET /reports/sales-summary | ✅ Exists |
| Top Products | GET /reports/top-products | ✅ Exists |
| Users | GET/POST/PUT /users | ✅ Exists |
| Roles | GET/POST/PUT /roles | ✅ Exists |
| Settings | PUT /organization | ✅ Exists (partial) |
| Profile | GET /users/me | ✅ Exists |
