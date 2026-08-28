# Jolinx Business OS — Security Architecture Baseline

> Date: 2026-08-19
> Classification: Internal — Engineering
> Scope: Business OS repository (`~/Documents/Workspaces/learning/business_app`)

---

## 1. Repository Architecture

### 1.1 Technology Stack

| Layer | Technology |
|---|---|
| Backend | ASP.NET Core 10, C# — modular monolith |
| Frontend (mobile) | Flutter/Dart — development stage, mostly mocked |
| Database | PostgreSQL 17 (Npgsql + EF Core) |
| Cache/Queue | Redis (in-memory fallback for dev) |
| Auth | JWT access (15min) + refresh (30-day rotating), BCrypt (cost 12) |
| Architecture | Clean Architecture + CQRS (MediatR), domain events, outbox pattern |
| Tenancy | Shared DB with `tenant_id` on every tenant-owned row |

### 1.2 Backend Project Structure

```
backend/
  src/
    Shared/           — cross-cutting (Result, PagedResult, etc.)
    Domain/           — aggregates: Identity, Tenants, Catalog, Inventory,
                        Pricing, Sales, Accounting, Platform
    Application/      — features, behaviors, validators, ports
    Infrastructure/   — EF repos, auth services, file storage
    API/              — minimal API endpoints, middleware
    Workers/          — background jobs (outbox flush, email)
    Notifications/    — email/SMS/push handlers
    Localizations/    — tax strategy adapters (TZ dual VAT)
    Modules/Sales/    — sales module boundary
  tests/
    BusinessOS.Tests/ — unit + integration (125 integration, 389 unit)
```

### 1.3 Existing Slices (Backend)

| Slice | Status | Tests |
|---|---|---|
| Auth (register/login/refresh/revoke) | ✅ Implemented | Unit + Integration |
| Identity (Users, Roles, Permissions) | ✅ Implemented | Unit + Integration |
| Organizations & Branches | ✅ Implemented | Unit + Integration |
| Product Catalog | ✅ Implemented | Unit + Integration |
| Inventory (Warehouses, Stock) | ✅ Implemented | Unit + Integration |
| Pricing Engine | ✅ Implemented | Unit + Integration |
| Sales POS | ✅ Implemented | Unit + Integration |
| Accounting (JE, Accounts) | ✅ Implemented | Unit only |
| Reporting & Tax | ✅ Implemented | Unit only |
| Dashboard | ✅ Implemented | Unit + Integration |

### 1.4 Test Status

| Type | Count | Status |
|---|---|---|
| Unit tests | 389 | ✅ All passing |
| Integration tests | 125 | ❌ All failing (require Postgres on localhost:5432) |
| E2E tests | 0 | Not implemented |

---

## 2. Flutter Status

### 2.1 Current State

**Flutter app exists but is NOT connected to the Business OS backend.**

| Component | Status |
|---|---|
| Authentication | ❌ Mock — hardcoded credentials (`admin`/`admin123`, etc.) |
| Backend connection | ❌ No HTTP client to Business OS API |
| Token storage | ❌ `SharedPreferences` (plaintext) — no `flutter_secure_storage` |
| Local database | ⚠️ Drift (SQLite) declared but disconnected |
| Offline-first | ❌ Not implemented |
| Route protection | ❌ `isLoggedIn` boolean only — no role checks |
| State management | ⚠️ Mixed BLoC + Provider (inconsistent) |

### 2.2 Hardcoded Credentials in Flutter

**CRITICAL:** `lib/features/auth/data/repositories/auth_repository.dart` contains:

```dart
final Map<String, String> _userPasswords = {
  'admin': 'admin123',
  'manager': 'manager123',
  'sales': 'sales123',
  'accountant': 'accountant123',
  'viewer': 'viewer123',
};
```

These are also duplicated in `login_page.dart` as `_sampleAccounts`.

### 2.3 Security Implications

- Anyone who decompiles the APK extracts all credentials
- No server-side auth validation
- User selection page bypasses auth entirely (`UserSelectionPage`)
- Registration, password reset, email verification are all fake
- `prefs.clear()` on logout destroys ALL app state
- Unencrypted SQLite database (no SQLCipher)
- No TLS certificate pinning

### 2.4 Flutter Dependencies Audit

| Package | Version | License | Purpose | Status |
|---|---|---|---|---|
| drift | 2.21.0 | MIT | SQLite ORM | ✅ Well-maintained |
| drift_flutter | 0.2.4 | MIT | Drift Flutter bindings | ✅ |
| http | 1.1.0 | BSD-3 | HTTP client | ✅ (will be replaced by Dio) |
| shared_preferences | 2.2.2 | BSD-3 | Key-value storage | ⚠️ Should be replaced for tokens |
| flutter_bloc | 8.1.3 | MIT | State management | ✅ |
| go_router | 13.0.0 | BSD-3 | Routing | ✅ |
| provider | any | MIT | State management | ⚠️ Conflicts with BLoC |
| flutter_blue_plus | 1.30.0 | BSD-3 | Bluetooth | ✅ |
| pdf | 3.10.4 | Apache-2.0 | PDF generation | ✅ |
| printing | 5.11.2 | Apache-2.0 | PDF printing | ✅ |
| sqlite3_flutter_libs | 0.24 | MIT | Native SQLite | ✅ |

**Missing security-critical packages:**
- `flutter_secure_storage` — encrypted token storage
- `dio` — HTTP client with interceptors
- `riverpod` — recommended state management (replacing BLoC+Provider)
- `json_serializable` / `freezed` — type-safe serialization

---

## 3. Backend Authentication Architecture

### 3.1 Implementation

| Aspect | Implementation |
|---|---|
| Algorithm | HMAC-SHA256 |
| Access token lifetime | 15 minutes |
| Refresh token lifetime | 30 days |
| Refresh rotation | ✅ Every refresh invalidates previous |
| Token reuse detection | ✅ Replayed token revokes entire family |
| Token hashing (storage) | SHA-256 (raw tokens never persisted) |
| Password hashing | BCrypt (work factor 12) |
| Account lockout | Configurable attempts → 15-min lockout |
| Email verification | ⚠️ Account created but `EmailVerified` never checked in auth |
| MFA/TOTP | Not implemented (planned for Phase 2) |

### 3.2 Audit Trail

| Event | Captured? |
|---|---|
| Successful login | ✅ |
| Failed login | ✅ |
| Registration | ✅ |
| Token refresh | ✅ |
| Logout (revoke) | ✅ |
| Password change | ⚠️ No audit event for password change |

### 3.3 Token Flow

```
Flutter → POST /api/v1/auth/register → {accessToken, refreshToken, tenantId, user}
Flutter → POST /api/v1/auth/login    → {accessToken, refreshToken, tenantId, user}
Flutter → POST /api/v1/auth/refresh  → {accessToken, refreshToken} (rotation)
Flutter → POST /api/v1/auth/revoke   → 204 (invalidates refresh token family)
```

---

## 4. Backend Authorization Architecture

### 4.1 RBAC Model

```
User → Role → Permission
  ↓
Tenant (via TenantId on all entities)
```

| Aspect | Implementation |
|---|---|
| Permission enforcement | `RequirePermission("permission.name")` on every endpoint |
| Permission claims | Embedded in JWT at issuance time |
| Permission cache | `PermissionCacheService` — 5-minute in-memory TTL |
| Permission resolution | Role-based + group-based paths |

### 4.2 Known Limitations

| Issue | Severity | Impact |
|---|---|---|
| JWT permissions stale until token expiry (15 min) | Low | Revoked permissions persist until token refresh |
| Permission cache per-process | Low | Multi-instance deploys: stale cache for up to 5 min |
| `RequirePermission` checks JWT claims, not DB | Low | Revoked role not reflected until token expiry |

### 4.3 Permission Catalog

All endpoints use `RequirePermission(PermissionNames.*)`:

- `Users.View/Create/Update/Delete`
- `Roles.View/Manage`
- `Dashboard.View`
- `Products.View/Create/Update/Delete`
- `Categories.View/Create/Update/Delete`
- `Brands.View/Create/Update/Delete`
- `Units.View/Create/Update/Delete`
- `Warehouses.View/Create/Update/Delete`
- `Inventory.View/Manage`
- `Pricing.View/Manage`
- `Sales.View/Create`
- `SalesReportsView/Export`
- `AccountingView/Create/Approve`

---

## 5. Multi-Tenancy Architecture

### 5.1 Isolation Model

| Mechanism | Implementation |
|---|---|
| DB isolation | Shared DB, `tenant_id` column on every row |
| Query guard | Repository layer filters by `TenantId` from JWT claims |
| Tenant resolution | `TenantId` extracted from JWT `ClaimTypes.NameIdentifier` or `TenantId` claim |
| Cross-tenant access | Returns `NotFound` (never leaks existence) |
| Concurrency | Postgres advisory locks per tenant |
| Schema isolation | Documented escape hatch for enterprise |

### 5.2 BOLA/IDOR Analysis

**Backend is well-protected:**

| Controller | Tenant Guard? | Notes |
|---|---|---|
| Identity (users/roles) | ✅ Repository-level filter | Cross-tenant returns NotFound |
| Organizations | ✅ Repository-level filter | |
| Branches | ✅ Repository-level filter | |
| Products | ✅ Repository-level filter | |
| Inventory | ✅ Repository-level filter | |
| Pricing | ✅ Repository-level filter | |
| Sales | ✅ Repository-level filter | |
| Accounting | ✅ Repository-level filter | |
| Reports | ✅ Repository-level filter | |
| Dashboard | ✅ Repository-level filter | |

**No `X-Tenant-Id` header is used.** Tenant is resolved from JWT claims only. This is a strong architectural choice — no header spoofing is possible.

### 5.3 Registration Creates Full Admin

**MEDIUM:** When a user registers (`RegisterUserCommand`), they get:
- Full `Administrator` role with ALL permissions
- A new tenant (organization)
- Auto-created `HQ` branch

There is no email verification gate before admin access is granted.

---

## 6. API Security Architecture

### 6.1 Endpoint Security Matrix

All endpoints require authentication (`[Authorize]` at group level). Permission enforcement is per-endpoint:

| Domain | Endpoints | Auth | Permission | Tenant Guard |
|---|---|---|---|---|
| Auth | `/api/v1/auth/*` | Public/Register, Auth/Login, Auth/Refresh | None (public) | N/A |
| Identity | `/api/v1/users/*`, `/api/v1/roles/*`, `/api/v1/permissions/*` | ✅ | `Users.*`, `Roles.*` | ✅ |
| Organizations | `/api/v1/organization` | ✅ | `Organization.View/Update` | ✅ |
| Branches | `/api/v1/branches/*` | ✅ | `Branches.*` | ✅ |
| Products | `/api/v1/products/*`, `/api/v1/categories/*`, etc. | ✅ | `Products.*`, `Categories.*` | ✅ |
| Inventory | `/api/v1/warehouses/*`, `/api/v1/inventory/*` | ✅ | `Warehouses.*`, `Inventory.*` | ✅ |
| Pricing | `/api/v1/price-lists/*`, `/api/v1/pricing/*` | ✅ | `Pricing.*` | ✅ |
| Sales | `/api/v1/sales/*` | ✅ | `Sales.*` | ✅ |
| Accounting | `/api/v1/accounts/*`, `/api/v1/journal-entries/*` | ✅ | `Accounting*` | ✅ |
| Reports | `/api/v1/reports/*` | ✅ | `SalesReports*` | ✅ |
| Dashboard | `/api/v1/dashboard/*` | ✅ | `Dashboard.View` | ✅ |
| Health | `/health/*` | ❌ None | None | N/A |

### 6.2 Input Validation

| Area | Enforcement |
|---|---|
| Command validation | FluentValidation pipeline behavior (rejects before handler) |
| Model binding | ASP.NET model state → ProblemDetails |
| SQL injection | EF Core parameterized queries only |
| File uploads | Kestrel 30 MB limit |
| CSV export | `CsvExportService` — comma/quote/newline escaping |

### 6.3 Error Handling

| Scenario | Response |
|---|---|
| Unhandled exception (prod) | `500 ProblemDetail` — no stack trace |
| Validation error | `400 ProblemDetail` with errors |
| Not found | `404 ProblemDetail` |
| Conflict | `409 ProblemDetail` |
| Forbidden | `403 ProblemDetail` |
| Rate limited | `429 TooManyRequests` |

---

## 7. Security Headers

`SecurityHeadersMiddleware` adds:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=(), geolocation=()
X-XSS-Protection: 0
```

**Missing:**
- `Strict-Transport-Security` (HSTS)
- `Content-Security-Policy`

---

## 8. Rate Limiting

| Scope | Policy | Key |
|---|---|---|
| Auth endpoints | 10 req/60s | IP address |
| Global endpoints | 60 req/60s | IP address |

**Issues:**
- IP-based keying breaks behind reverse proxy (all users share IP)
- `/auth/revoke` (logout) consumes auth rate limit (usability issue)

---

## 9. CORS

| Environment | Configuration |
|---|---|
| Production | Explicit origins from `Cors:AllowedOrigins` config |
| Development | `AllowAnyOrigin()` when config is empty |

**Issue:** If `ASPNETCORE_ENVIRONMENT=Development` is misconfigured in production, CORS becomes fully open.

---

## 10. Secrets Management

### 10.1 Committed Secrets

| File | Secret | Severity |
|---|---|---|
| `src/API/appsettings.json` | DB password `Joseph662.` + JWT placeholder | **CRITICAL** |
| `src/Workers/appsettings.json` | Same DB password + JWT placeholder | **CRITICAL** |
| `src/Infrastructure/BusinessDbContextFactory.cs:16` | DB password hardcoded in fallback | **CRITICAL** |
| `memory/project.md:261` | DB password documented in project memory | Medium |

### 10.2 JWT Secret Weakness

The JWT secret is `"dev-secret-please-replace-with-a-long-random-key-64-chars-minimum"` — predictable text, not cryptographically random. There is **no minimum length validation** at startup.

**Recommendation:** Add startup check: `if (jwtOptions.Secret.Length < 64) throw`.

---

## 11. Audit System

### 11.1 Audit Pipeline

`AuditBehavior` (MediatR pipeline) automatically captures:
- Command name + handler
- User ID + Tenant ID
- Redacted parameters (sensitive terms masked)

### 11.2 Audit Table

`AuditLog` in `Platform` schema: command, userId, tenantId, timestamp, parameters (redacted).

### 11.3 Redaction

Sensitive terms: `password`, `secret`, `token`, `apikey`, `authorization`, `key`.

**Issue:** `"key"` is overly broad — redacts `PrimaryKey`, `ForeignKey`, etc.

---

## 12. Offline-First Architecture

### 12.1 Current State

- Drift (SQLite) schema declared with 11 tables but **disconnected from the running app**
- No sync mechanism implemented
- No offline CRUD capability
- No conflict resolution

### 12.2 Security Implications (When Implemented)

| Concern | Recommendation |
|---|---|
| Local DB encryption | Use SQLCipher or platform-encrypted storage |
| Customer data on device | Minimize PII stored locally; encrypt at rest |
| Financial data | Never trust client-side calculations |
| Auth tokens | `flutter_secure_storage` (Keychain/Keystore) |
| Sync conflicts | Server is authoritative |

---

## 13. Known Vulnerabilities Summary

### Critical

| # | Finding | Location | Status |
|---|---|---|---|
| 1 | Hardcoded DB password in `appsettings.json` | `src/API/appsettings.json` | **Not fixed** |
| 2 | DB password in design-time factory | `src/Infrastructure/BusinessDbContextFactory.cs:16` | **Not fixed** |
| 3 | Flutter hardcoded credentials | `lib/features/auth/data/repositories/auth_repository.dart` | **Not fixed** |
| 4 | Flutter auth is entirely mocked | `lib/features/auth/` | **Not fixed** |

### High

| # | Finding | Location | Status |
|---|---|---|---|
| 5 | JWT secret not validated for length/entropy | `DependencyInjection.cs` | **Not fixed** |
| 6 | CORS `AllowAnyOrigin()` in Development | `src/API/Program.cs:152-158` | **Not fixed** |
| 7 | Auth rate limiter keyed on IP (broken behind proxy) | `src/API/Program.cs` | **Not fixed** |
| 8 | Flutter tokens in `SharedPreferences` (plaintext) | `lib/shared/providers/user_provider.dart` | **Not fixed** |
| 9 | Flutter unencrypted SQLite database | `lib/shared/database/app_database.dart` | **Not fixed** |
| 10 | Flutter no route-level RBAC | `lib/app_router.dart` | **Not fixed** |

### Medium

| # | Finding | Location | Status |
|---|---|---|---|
| 11 | Missing HSTS header | `SecurityHeadersMiddleware.cs` | **Not fixed** |
| 12 | Registration grants full admin without email verification | `RegisterUserCommand.cs` | **Not fixed** |
| 13 | No progressive account lockout | `User.cs` | **Not fixed** |
| 14 | Audit redaction `"key"` overly broad | `AuditBehavior.cs` | **Not fixed** |
| 15 | Flutter Android release signed with debug keys | `android/app/build.gradle.kts` | **Not fixed** |
| 16 | Flutter `prefs.clear()` destroys all state on logout | `user_provider.dart` | **Not fixed** |
| 17 | Flutter debug signing + placeholder application ID | `android/app/build.gradle.kts` | **Not fixed** |

### Low

| # | Finding | Location | Status |
|---|---|---|---|
| 18 | Permission cache per-process (no cross-instance) | `PermissionCacheService.cs` | **Not fixed** |
| 19 | JWT permissions stale until token expiry | JWT claims | **Not fixed** |
| 20 | Password change doesn't revoke sessions | `User.cs` | **Not fixed** |
| 21 | Flutter mixed state management (BLoC + Provider) | Multiple | **Not fixed** |

---

## 14. Recommended Flutter Security Stack

| Package | Purpose | License |
|---|---|---|
| `dio` | HTTP client with interceptors | BSD-3 |
| `flutter_secure_storage` | Encrypted token storage | BSD-3 |
| `riverpod` + `riverpod_annotation` | State management (replace BLoC+Provider) | MIT |
| `go_router` | Routing (already present) | BSD-3 |
| `drift` | Local SQLite (already present) | MIT |
| `json_serializable` + `freezed` | Type-safe models | MIT |
| `connectivity_plus` | Network status | MIT |
| `cached_network_image` | Offline image caching | BSD-3 |

**All licenses are compatible with commercial SaaS.**

---

## 15. Security Test Coverage

### 15.1 Backend Tests

| Area | Unit | Integration | E2E |
|---|---|---|---|
| Auth (register/login/refresh/revoke) | ✅ | ✅ | ❌ |
| Account lockout | ❌ | ✅ | ❌ |
| Refresh rotation replay | ✅ | ✅ | ❌ |
| RBAC permission cache | ✅ | ❌ | ❌ |
| Last-admin concurrent guard | ✅ | ✅ | ❌ |
| Tenant isolation | ✅ | ✅ | ❌ |
| Rate limiting | ❌ | ❌ | ❌ |
| CORS rejection | ❌ | ❌ | ❌ |
| Soft-delete enforcement | ❌ | ❌ | ❌ |
| CSV path traversal | ❌ | ❌ | ❌ |
| Audit trail completeness | ✅ | ✅ | ❌ |

### 15.2 Flutter Tests

**No security tests exist.** The Flutter app has no authentication tests, no token storage tests, no encryption tests.

### 15.3 Missing Tests to Add

1. Account lockout integration test
2. Refresh token rotation replay integration test
3. CORS rejection test (cross-origin authenticated request)
4. Rate limit 429 response test
5. Soft-delete enforcement integration test
6. CSV export filename sanitization test
7. Permission cache invalidation after role change
8. Progressive lockout (extended lockout after repeated lockouts)
9. Password change → session revocation test
10. Tenant isolation comprehensive test (all domains)

---

## 16. Readiness Assessment

### Backend: READY for Flutter integration (with caveats)

| Criteria | Status |
|---|---|
| JWT auth flow | ✅ Working |
| Refresh token rotation | ✅ Working |
| Permission enforcement | ✅ Every endpoint |
| Tenant isolation | ✅ Every query |
| Input validation | ✅ FluentValidation |
| Error handling | ✅ ProblemDetails |
| Audit trail | ✅ Automated pipeline |
| Security headers | ✅ Partial (no HSTS/CSP) |
| Rate limiting | ✅ Auth endpoints |
| Hardcoded secrets | ❌ Must rotate before production |

### Flutter: NOT READY for backend integration

| Criteria | Status |
|---|---|
| Real auth flow | ❌ Mock only |
| HTTP client to API | ❌ Not connected |
| Secure token storage | ❌ SharedPreferences |
| Role-based routing | ❌ Boolean only |
| Encrypted local DB | ❌ Plain SQLite |
| Offline-first | ❌ Not implemented |
| Production signing | ❌ Debug keys |

---

## 17. Final Classification

**BACKEND:** SECURITY FOUNDATION READY
- The .NET backend has a solid security architecture
- JWT + refresh rotation + BCrypt + RBAC + tenant isolation all working
- Hardcoded secrets must be rotated before any deployment
- Missing HSTS/CSP headers should be added

**FLUTTER:** SECURITY FOUNDATION NOT READY
- All auth is mocked with hardcoded credentials
- No connection to Business OS backend
- No secure storage, no encryption, no RBAC
- Must be rebuilt from scratch to connect to the real backend

---

## 18. Files Requiring Modification

### Backend (Low effort — security hardening)

| File | Change | Priority |
|---|---|---|
| `src/API/appsettings.json` | Remove committed secrets, use env vars | P0 |
| `src/Workers/appsettings.json` | Same | P0 |
| `src/Infrastructure/BusinessDbContextFactory.cs` | Remove hardcoded password | P0 |
| `src/API/Program.cs` | Add HSTS header, fix CORS dev fallback | P1 |
| `src/Infrastructure/Security/JwtTokenService.cs` | Add secret length validation | P1 |
| `src/API/Middleware/SecurityHeadersMiddleware.cs` | Add HSTS | P1 |

### Flutter (High effort — complete rebuild needed)

| File | Change | Priority |
|---|---|---|
| All files under `lib/features/auth/` | Replace mock auth with real API calls | P0 |
| `lib/shared/providers/user_provider.dart` | Replace SharedPreferences with flutter_secure_storage | P0 |
| `lib/shared/database/app_database.dart` | Add SQLCipher encryption | P1 |
| `lib/app_router.dart` | Add role-based route guards | P1 |
| `pubspec.yaml` | Add dio, flutter_secure_storage, riverpod | P1 |
| `android/app/build.gradle.kts` | Add production signing config | P2 |

---

## 19. Whether Business OS is Ready for Flutter Integration

**BACKEND: YES** — with P0 secret rotation done first.

**FLUTTER: NO** — the existing Flutter app is a prototype with mocked auth. It must be rebuilt to:
1. Connect to the real Business OS API endpoints
2. Use `flutter_secure_storage` for tokens
3. Implement real JWT auth flow
4. Add role-based route protection
5. Use encrypted local database

The backend provides all the API contracts needed. The Flutter app needs a clean rewrite of the auth layer, not a patch.
