# Implementation Plan — Users, Roles, Profile Fixes

> No new features. Fix broken plumbing between backend and Flutter.
> Backend is 95% done. Flutter has 12 bugs + 4 missing capabilities.

---

## Security Requirements (mandatory for every phase)

### Threat Model

| Threat | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Account takeover via password change | Critical | High without fix | Verify current password + BCrypt + revoke tokens |
| Privilege escalation via profile update | Critical | Medium | `ITenantContext.UserId` only; no email/role/branch fields accepted |
| Brute force password guessing | High | Medium | Stricter rate limit (`"auth"` policy) on `/me/password` |
| Credential logging in Flutter | High | Low | Never log password request bodies; dispose controllers |
| Stored XSS via fullName | Low | Low | Server trim + max length; Flutter escapes output |
| Session persistence after password change | Medium | High | Revoke all refresh tokens on password change |

### Existing Security Controls (already in place)

| Control | Status | Location |
|---|---|---|
| JWT Bearer auth | ✅ | `AuthEndpoints.cs` |
| RBAC (`RequirePermission`) | ✅ | All endpoints |
| Rate limiting | ✅ | `"auth"` (login) + `"global"` (API) |
| Security headers | ✅ | `SecurityHeadersMiddleware.cs` |
| Audit pipeline | ✅ | `AuditBehavior.cs` — auto-logs all non-GET commands |
| Sensitive field redaction | ✅ | Audit logs redact `password`, `secret`, `token`, `key` |
| Account lockout | ✅ | `User.RegisterFailedLogin()` |
| Email verification | ✅ | Gates unverified accounts |
| Tenant isolation | ✅ | `ITenantContext.UserId` on every query |
| BCrypt hashing | ✅ | `IPasswordHasher` |

### Security Rules for New Code

1. **Password change handler MUST:**
   - Verify current password via `IPasswordHasher.Verify(currentPassword, user.PasswordHash)`
   - Reject with `Error.Validation("Current password is incorrect.")` on failure
   - Hash new password via `IPasswordHasher.Hash(newPassword)`
   - Call `user.ChangePassword(hashedNewPassword)`
   - Revoke ALL refresh tokens via `IRefreshTokenRepository.RevokeAllForUserAsync(tenantId, userId)`
   - Validate password policy (≥8 chars, upper/lower/digit/special — same as registration)
   - Audit log (automatic via `AuditBehavior`, passwords redacted by `SensitiveTerms`)

2. **Profile update handler MUST:**
   - Load user via `ITenantContext.UserId` (NEVER from route param)
   - Accept ONLY `fullName` and `phone` fields
   - REJECT any attempt to change `email`, `roleIds`, `branchIds`, `permissions`, `isActive`
   - Normalize phone via `PhoneNumber.Normalize()` + uniqueness check
   - Trim `fullName` server-side, enforce max 200 chars

3. **Rate limiting:**
   - Password change endpoint uses `"auth"` policy (stricter), NOT `"global"`
   - Profile update uses `"global"` policy (standard)

4. **Flutter credential handling:**
   - Password fields must never be logged or stored in local storage
   - `ApiClient` must not log request bodies on `/me/password` calls
   - `TextEditingController` for passwords must be disposed properly

---

## Root Cause Summary

| # | File | Bug | Impact |
|---|---|---|---|
| 1 | Backend | No `PUT /api/v1/users/me` endpoint | Profile update 404 |
| 2 | Backend | No `PUT /api/v1/users/me/password` endpoint | Password change 404 |
| 3 | Backend | `GET /users/me` returns `FullName` not `displayName`, no `tenantName` | Profile shows empty fields |
| 4 | `user_repository.dart:70-87` | `roles()` parses flat array as paged `{items, total}` | Empty role dropdown |
| 5 | `role_repository.dart:16-33` | `list()` sends `page`/`pageSize`, parses as paged | Empty roles page |
| 6 | `role_repository.dart:43-59` | `create()` sends `permissions` in body (backend ignores) | Permissions silently lost |
| 7 | `role_repository.dart:95-103` | `setRolePermissions()` sends raw list, not `{permissionNames:[...]}` | 400 error |
| 8 | `user_form_page.dart:201` | Sends `displayName` instead of `fullName` | Validation error |
| 9 | `user_form_page.dart:203` | Sends `roleIds` on update (backend ignores, only name/phone) | No-op but misleading |
| 10 | `user_form_page.dart:42` | Edit loads `user['displayName']` but backend returns `fullName` | Empty edit form |
| 11 | `profile_repository.dart:56-57` | `updateProfile()` sends `displayName` but backend expects `fullName` | Profile update broken |
| 12 | `profile_repository.dart:22-30` | `fromJson()` maps `displayName`/`tenantName` which backend doesn't return | Empty profile |

---

## Phase 1 — Backend: Self-Service Profile Endpoints (3 files)

### 1a. Add `UpdateMyProfileCommand` + `ChangeMyPasswordCommand`

**File:** `backend/src/Application/Features/Users/Commands/UpdateMyProfileCommand.cs` (new)

```csharp
public sealed record UpdateMyProfileCommand(string FullName, string? Phone) : IRequest<Result<UserDto>>;

public sealed class UpdateMyProfileCommandHandler
    : IRequestHandler<UpdateMyProfileCommand, Result<UserDto>>
{
    // SECURITY: Load user via ITenantContext.UserId ONLY — never from route param
    // SECURITY: Accept ONLY fullName + phone — reject email/roleIds/branchIds/isActive
    // SECURITY: Phone normalization + uniqueness check (same as UpdateUserCommand)
    // SECURITY: fullName trimmed server-side, max 200 chars enforced by validator
}
```

**File:** `backend/src/Application/Features/Users/Commands/ChangeMyPasswordCommand.cs` (new)

```csharp
public sealed record ChangeMyPasswordCommand(
    string CurrentPassword,
    string NewPassword) : IRequest<Result>;

public sealed class ChangeMyPasswordCommandHandler
    : IRequestHandler<ChangeMyPasswordCommand, Result>
{
    // SECURITY: Load user via ITenantContext.UserId
    // SECURITY: Verify current password via IPasswordHasher.Verify(currentPassword, user.PasswordHash)
    //   → Reject with Error.Validation("Current password is incorrect.") on failure
    // SECURITY: Hash new password via IPasswordHasher.Hash(newPassword)
    // SECURITY: Call user.ChangePassword(hashedNewPassword)
    // SECURITY: Revoke ALL refresh tokens via IRefreshTokenRepository.RevokeAllForUserAsync()
    //   → Stolen sessions die immediately
    // SECURITY: Validate password policy (≥8 chars, upper/lower/digit/special)
    // SECURITY: Audit log auto-captured by AuditBehavior (passwords redacted by SensitiveTerms)
}
```

**Validators** in `backend/src/Application/Features/Users/UserValidators.cs` (add 2 validators):
- `UpdateMyProfileCommandValidator`: FullName required max 200, Phone max 30
- `ChangeMyPasswordCommandValidator`: CurrentPassword required, NewPassword required + password policy (≥8 chars, upper/lower/digit/special)

### 1b. Wire up endpoints

**File:** `backend/src/API/Endpoints/AuthEndpoints.cs` (add 2 lines)

```csharp
// SECURITY: Password change uses "auth" rate limit policy (stricter: ~5 req/60s)
//   NOT "global" — prevents brute force password guessing
users.MapPut("/me/password", ChangeMyPasswordAsync)
    .RequireRateLimiting("auth")
    .WithName("ChangeMyPassword");

// SECURITY: Profile update uses "global" rate limit policy (standard)
// SECURITY: No specific permission required — self-service (authenticated only)
users.MapPut("/me", UpdateMyProfileAsync)
    .RequireRateLimiting("global")
    .WithName("UpdateMyProfile");
```

### 1c. Fix `GetCurrentUserQuery` to include tenant name

**File:** `backend/src/Application/Features/Users/Queries/GetCurrentUserQuery.cs`

Load tenant via `ITenantContext.TenantId` → `ITenantRepository.GetByIdAsync`, include `tenant.Name` in a new `CurrentUserDto`:

**File:** `backend/src/Application/Features/Auth/Dtos/AuthDtos.cs` (add)

```csharp
public sealed record CurrentUserDto(
    Guid Id, Guid TenantId, string Email, string FullName, string? Phone,
    bool IsActive, bool EmailVerified, IReadOnlyList<string> Permissions,
    string TenantName, IReadOnlyList<string> RoleNames);
```

The `GetCurrentUserQueryHandler` already loads user with roles — just add tenant name lookup and role name projection. Return `CurrentUserDto` instead of `UserDto`.

---

## Phase 2 — Flutter: Typed Models (4 files)

Replace all `Map<String, dynamic>` usage with proper typed models. **One model per domain, used everywhere.**

### 2a. User model

**File:** `lib/features/users/data/user_models.dart` (new)

```dart
class IdentityUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final bool isActive;
  final bool emailVerified;
  final bool isLockedOut;
  final List<String> roleIds;
  final List<String> branchIds;
  final String? defaultBranchId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory IdentityUser.fromJson(Map<String, dynamic> json) => ...;
}
```

### 2b. Role model

**File:** `lib/features/roles/data/role_models.dart` (new)

```dart
class Role {
  final String id;
  final String name;
  final String? description;
  final bool isSystem;
  final List<String> permissionNames;
  final DateTime createdAt;

  factory Role.fromJson(Map<String, dynamic> json) => ...;
}

class Permission {
  final String name;
  final String? description;

  factory Permission.fromJson(Map<String, dynamic> json) => ...;
}
```

### 2c. Profile model (update existing)

**File:** `lib/features/profile/data/profile_repository.dart` — update `UserProfile` to match `CurrentUserDto`:

```dart
class UserProfile {
  final String id;
  final String fullName;   // was displayName
  final String email;
  final String? phone;
  final String tenantName; // now actually populated
  final List<String> roleNames; // now actually populated
  final List<String> permissions;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] ?? '',
    fullName: json['fullName'] ?? '',  // was displayName
    email: json['email'] ?? '',
    phone: json['phone'],
    tenantName: json['tenantName'] ?? '',  // now populated by backend
    roleNames: (json['roleNames'] as List?)?.cast<String>() ?? [],
    permissions: (json['permissions'] as List?)?.cast<String>() ?? [],
  );
}
```

---

## Phase 3 — Flutter: Fix Repositories (4 files)

### 3a. Fix `UserRepository`

**File:** `lib/features/users/data/user_repository.dart`

- `list()`: Keep paged parsing (backend returns `PagedResult` with `{items, total}`) — **this is correct**
- `roles()`: Change to parse flat `IReadOnlyList<RoleDto>` → return `List<Role>` (not paged):

```dart
Future<List<Role>> roles() async {
  final response = await _apiClient.get<dynamic>('/api/v1/roles');
  // Backend returns flat array, not paged
  return (response.data as List<dynamic>)
      .map((raw) => Role.fromJson(Map<String, dynamic>.from(raw)))
      .toList();
}
```

### 3b. Fix `RoleRepository`

**File:** `lib/features/roles/data/role_repository.dart`

- `list()`: Remove `page`/`pageSize` params, parse flat array:

```dart
Future<List<Role>> list() async {
  final response = await _apiClient.get<dynamic>('/api/v1/roles');
  return (response.data as List<dynamic>)
      .map((raw) => Role.fromJson(Map<String, dynamic>.from(raw)))
      .toList();
}
```

- `create()`: Remove `permissions` param (set separately):

```dart
Future<Role> create({required String name, String? description}) async {
  final response = await _apiClient.post<dynamic>('/api/v1/roles', body: {
    'name': name,
    'description': description,
  });
  return Role.fromJson(Map<String, dynamic>.from(response.data as Map));
}
```

- `permissions()`: Return `List<Permission>`:

```dart
Future<List<Permission>> permissions() async {
  final response = await _apiClient.get<dynamic>('/api/v1/permissions');
  return (response.data as List<dynamic>)
      .map((raw) => Permission.fromJson(Map<String, dynamic>.from(raw)))
      .toList();
}
```

- `rolePermissions()`: Already correct (returns `List<String>`).

- `setRolePermissions()`: Wrap in `{permissionNames: [...]}`:

```dart
Future<void> setRolePermissions(String roleId, List<String> permissions) async {
  await _apiClient.put<dynamic>(
    '/api/v1/roles/$roleId/permissions',
    body: {'permissionNames': permissions},
  );
}
```

### 3c. Fix `ProfileRepository`

**File:** `lib/features/profile/data/profile_repository.dart`

- `updateProfile()`: Send `fullName` (not `displayName`):

```dart
Future<UserProfile> updateProfile({String? fullName, String? phone}) async {
  final body = <String, dynamic>{};
  if (fullName != null) body['fullName'] = fullName;
  if (phone != null) body['phone'] = phone;
  // ... same PUT /users/me call
}
```

- `changePassword()`: Already calls `PUT /users/me/password` — will work once backend endpoint exists.
  - **SECURITY: Must not log the request body.**
  - **SECURITY: Password controllers must be disposed properly in the UI.**

### 3d. Fix providers

**File:** `lib/features/roles/data/role_providers.dart`

```dart
final permissionsProvider = FutureProvider<List<Permission>>((ref) async {
  final repository = ref.watch(roleRepositoryProvider);
  return repository.permissions();
});
```

**File:** `lib/features/users/data/user_providers.dart`

```dart
final rolesProvider = FutureProvider<List<Role>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.roles();
});
```

Remove `PagedRoles`, `RoleOption`, `PagedUsers` wrapper classes — use typed models directly.

---

## Phase 4 — Flutter: Fix Controllers (3 files)

### 4a. `UsersController`

**File:** `lib/features/users/application/users_controller.dart`

```dart
class UsersLoaded extends UsersState {
  final List<IdentityUser> items;
  final int total;
}
```

Update `load()` to map `PagedUsers` items to `List<IdentityUser>`.

### 4b. `RolesController`

**File:** `lib/features/roles/application/roles_controller.dart`

```dart
class RolesLoaded extends RolesState {
  final List<Role> items;
}
```

Update `load()` to call `_repository.list()` which now returns `List<Role>` (flat, not paged).

Update `create()` to not send permissions:

```dart
Future<void> create({required String name, String? description, List<String>? permissions}) async {
  final role = await _repository.create(name: name, description: description);
  if (permissions != null && permissions.isNotEmpty) {
    await _repository.setRolePermissions(role.id, permissions);
  }
  await load();
}
```

### 4c. `ProfileController`

**File:** `lib/features/profile/application/profile_controller.dart`

- `updateProfile({String? fullName, String? phone})` — rename param from `displayName` to `fullName`
- `changePassword()` — already correct

---

## Phase 5 — Flutter: Fix UI Pages (4 files)

### 5a. `UserFormPage`

**File:** `lib/features/users/presentation/pages/user_form_page.dart`

- **Line 42:** `_displayNameController.text = user['displayName']` → use `IdentityUser.fullName`
- **Line 201:** `'displayName': ...` → `'fullName': _displayNameController.text.trim()`
- **Line 203:** Remove `'roleIds': _selectedRoleIds` from update body (roles set via `PUT /users/{id}/roles`)
- **Role loading:** Use typed `List<Role>` instead of `PagedRoles`
- **Add role assignment on create:** After creating user, call `PUT /users/{id}/roles` with selected role IDs

### 5b. `RolesPage`

**File:** `lib/features/users/presentation/pages/roles_page.dart`

- Use typed `Role` instead of `Map<String, dynamic>`
- Add delete button (with system role check)

### 5c. `RoleFormPage`

**File:** `lib/features/users/presentation/pages/role_form_page.dart`

- Use typed `Permission` instead of `Map<String, dynamic>`
- `perm['displayName']` → `perm.description ?? perm.name` (backend `PermissionDto` has `Name` + `Description`)

### 5d. `ProfilePage`

**File:** `lib/features/profile/presentation/pages/profile_page.dart`

- `profile.displayName` → `profile.fullName`
- `profile.tenantName` — now populated by backend
- `_editName()` sends `fullName:` to controller
- `_changePassword()` — already correct
- **SECURITY: All three password `TextEditingController`s (current, new, confirm) MUST be disposed in the dialog's `dispose()` or via `.then((_) => controller.dispose())` to clear credentials from memory.**

---

## Phase 6 — Flutter: Add Missing UI (3 files)

### 6a. User status toggle

**File:** `lib/features/users/presentation/pages/users_page.dart`

Add long-press menu or trailing popup with "Activate"/"Deactivate" option:
- Call `PATCH /api/v1/users/{id}/status` with `{ isActive: !current }`
- Add `toggleStatus(String id, bool isActive)` to `UserRepository` + `UsersController`

### 6b. User delete

**File:** `lib/features/users/presentation/pages/users_page.dart`

Add delete option in the same popup menu:
- Call `DELETE /api/v1/users/{id}`
- Add `delete(String id)` to `UserRepository` + `UsersController`

### 6c. Role delete

**File:** `lib/features/users/presentation/pages/roles_page.dart`

Add delete button (hidden for system roles):
- Call `DELETE /api/v1/roles/{id}`
- Add `delete(String id)` to `RoleRepository` + `RolesController`

### 6d. Add repository methods

**File:** `lib/features/users/data/user_repository.dart` — add:

```dart
Future<void> setStatus(String id, bool isActive) async {
  await _apiClient.patch<dynamic>('/api/v1/users/$id/status', body: {'isActive': isActive});
}

Future<void> delete(String id) async {
  await _apiClient.delete<dynamic>('/api/v1/users/$id');
}

Future<void> setRoles(String userId, List<String> roleIds) async {
  await _apiClient.put<dynamic>('/api/v1/users/$userId/roles', body: {'roleIds': roleIds});
}
```

**File:** `lib/features/roles/data/role_repository.dart` — add:

```dart
Future<void> delete(String id) async {
  await _apiClient.delete<dynamic>('/api/v1/roles/$id');
}
```

---

## Phase 7 — Tests

### Backend tests (2 new)

**`ChangeMyPasswordCommand` tests:**
- Happy path: correct current password → new password set, all refresh tokens revoked
- Wrong current password → `Error.Validation("Current password is incorrect.")`
- Weak new password → validation error (policy enforcement)
- Inactive user → rejected
- Audit log created with redacted fields

**`UpdateMyProfileCommand` tests:**
- Happy path: fullName + phone updated, domain event raised
- Duplicate phone → `Error.Conflict`
- Invalid phone → `Error.Validation`
- fullName empty → validation error
- **SECURITY: Attempting to send email/roleIds/isActive in body → fields silently ignored (handler only reads fullName + phone)**

### Flutter tests
- Update existing controller tests for typed models
- Verify `UserRepository.roles()` parses flat array
- Verify `RoleRepository.list()` parses flat array
- Verify `RoleRepository.setRolePermissions()` sends wrapped body
- **Verify password controllers are disposed after dialog close**

---

## File Change Summary

| # | File | Action | Lines Changed | Security Impact |
|---|---|---|---|---|
| 1 | `backend/src/Application/Features/Users/Commands/UpdateMyProfileCommand.cs` | NEW | ~45 | Self-scoped, no privilege escalation |
| 2 | `backend/src/Application/Features/Users/Commands/ChangeMyPasswordCommand.cs` | NEW | ~60 | Password verify + BCrypt + token revocation |
| 3 | `backend/src/Application/Features/Users/UserValidators.cs` | EDIT | +20 | Password policy enforcement |
| 4 | `backend/src/Application/Features/Auth/Dtos/AuthDtos.cs` | EDIT | +10 | — |
| 5 | `backend/src/Application/Features/Users/Queries/GetCurrentUserQuery.cs` | EDIT | +15 | — |
| 6 | `backend/src/API/Endpoints/AuthEndpoints.cs` | EDIT | +15 | `"auth"` rate limit on password change |
| 7 | `lib/features/users/data/user_models.dart` | NEW | ~50 | — |
| 8 | `lib/features/roles/data/role_models.dart` | NEW | ~40 | — |
| 9 | `lib/features/users/data/user_repository.dart` | EDIT | rewrite | — |
| 10 | `lib/features/roles/data/role_repository.dart` | EDIT | rewrite | — |
| 11 | `lib/features/profile/data/profile_repository.dart` | EDIT | ~20 | No credential logging |
| 12 | `lib/features/users/data/user_providers.dart` | EDIT | ~10 | — |
| 13 | `lib/features/roles/data/role_providers.dart` | EDIT | ~10 | — |
| 14 | `lib/features/users/application/users_controller.dart` | EDIT | ~15 | — |
| 15 | `lib/features/roles/application/roles_controller.dart` | EDIT | ~20 | — |
| 16 | `lib/features/profile/application/profile_controller.dart` | EDIT | ~5 | — |
| 17 | `lib/features/users/presentation/pages/user_form_page.dart` | EDIT | ~20 | — |
| 18 | `lib/features/users/presentation/pages/users_page.dart` | EDIT | +30 | — |
| 19 | `lib/features/users/presentation/pages/roles_page.dart` | EDIT | +15 | — |
| 20 | `lib/features/users/presentation/pages/role_form_page.dart` | EDIT | ~10 | — |
| 21 | `lib/features/profile/presentation/pages/profile_page.dart` | EDIT | ~10 | Password controller disposal |

**Total: 6 new files, 15 edited files, ~0 duplicate logic.**

---

## Execution Order

1. **Phase 1** (backend) — independent, no Flutter impact yet
2. **Phase 2** (models) — create once, used by phases 3-6
3. **Phase 3** (repositories) — fix API contract mismatches
4. **Phase 4** (controllers) — adapt to typed models from phase 2+3
5. **Phase 5** (UI fixes) — adapt to typed models from phase 2+3+4
6. **Phase 6** (missing UI) — new buttons, uses phase 3 repository methods
7. **Phase 7** (tests) — verify everything works

Each phase can be verified independently before moving to the next.

---

## Security Verification Checklist (before merge)

- [ ] `ChangeMyPasswordCommand` verifies current password before allowing change
- [ ] `ChangeMyPasswordCommand` hashes new password with BCrypt
- [ ] `ChangeMyPasswordCommand` revokes all refresh tokens after password change
- [ ] `ChangeMyPasswordCommand` validates password policy (≥8 chars, upper/lower/digit/special)
- [ ] `UpdateMyProfileCommand` loads user via `ITenantContext.UserId` (not route param)
- [ ] `UpdateMyProfileCommand` accepts ONLY `fullName` + `phone` (no email/roles/branch/isActive)
- [ ] `UpdateMyProfileCommand` normalizes phone + uniqueness check
- [ ] Password change endpoint uses `"auth"` rate limit policy (not `"global"`)
- [ ] Profile update endpoint uses `"global"` rate limit policy
- [ ] Audit logs capture both commands (automatic via `AuditBehavior`)
- [ ] Password fields are redacted in audit logs (via `SensitiveTerms`)
- [ ] Flutter `ApiClient` does not log password request bodies
- [ ] Flutter password `TextEditingController`s are disposed after dialog close
- [ ] No hardcoded secrets or credentials in code
- [ ] Backend builds `--warnaserror` clean
- [ ] `flutter analyze` clean (0 issues)
- [ ] All existing tests pass (no regressions)
- [ ] New backend tests pass (password verify, profile update, phone uniqueness)
