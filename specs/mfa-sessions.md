# Feature Spec — MFA & Session Management (Slice M14)

## Feature

TOTP two-factor authentication for server-side logins, hashed recovery codes, and
user-visible device session management (list / revoke / revoke-all).

## Purpose

A stolen refresh token is currently **unbounded**: it rotates for 14 days
(`AuthConstants.RefreshTokenDays`) with no way for the owner to see or cut off a
device they no longer recognise. `memory/project.md` (M10.3) already logged
"no remote revoke-my-devices / new-device alert" as accepted debt.

This slice closes that gap:

- **MFA** raises the cost of a stolen password. Password alone no longer yields a session.
- **Sessions** make sessions visible and revocable, so a lost phone is a settings action,
  not a support ticket.

Why server-side rather than leaning on the existing device gate: M9.2/M9.2b already
protect the *device* with biometrics + PIN and idle lock. That protects a device already
in the owner's hand. It does nothing when the password leaks — e.g. a phishing page, or a
shared password between a shop owner and a relative. MFA covers that threat; the local
gate does not.

### Scope decisions (agreed)

| Decision | Choice | Rationale |
| --- | --- | --- |
| Who must enrol | **Owner-level users only**, enforced by tenant policy; staff may opt in | Forcing every cashier through TOTP on a shared shop terminal destroys throughput and pushes users to shared passwords, which is worse. The account that moves money is the one worth protecting. |
| Does MFA gate offline unlock | **No** | Offline unlock already requires a device-bound biometric/PIN through `AppLockPolicy` + the 7-day trusted-device token. That is a separate trust boundary. Gating it on a *server* check would make offline impossible — the exact failure M9.2 was built to eliminate. |
| Social OAuth | **Out of scope** | Not the buyer; adds provider dependency and support surface. |
| SMS OTP as second factor | **Deferred** | Needs an SMS gateway with per-message cost and delivery failure modes. TOTP is free, offline-capable, and works on the cheap Android devices in our market. |

## Business rules

### Two-factor enrolment

1. Enrolment is two-step: `setup` returns a **pending** secret; `confirm` activates it
   only after the user proves possession by entering a valid code generated from it.
2. A pending secret must never be able to activate itself. `ConfirmTwoFactorCommand`
   verifies a real TOTP code before persisting `TwoFactorEnabled = true`.
3. Starting enrolment replaces any unconfirmed pending secret (re-running setup is safe
   and idempotent — a user who abandons setup just gets a fresh secret).
4. Confirming replaces any previously active secret. Re-confirming rotates the secret.
5. `Disable` requires the current code. Disabling clears the secret, the recovery codes,
   and the enabled flag in one mutation, then writes an audit row — a security-relevant
   change that must never be silent.

### Recovery codes

6. Ten single-use codes, generated at enrolment and on explicit regeneration.
7. **Only hashes are stored.** The raw codes are returned exactly once, in the response
   to the generate/regenerate call. They cannot be recovered later.
8. Each code is consumed on first successful use and marked `UsedAt`; a used code can
   never authenticate again.
9. Regenerating revokes every outstanding code from the previous batch.
10. Verification accepts either a 6-digit TOTP code **or** a recovery code, in one
    request. The client decides which based on what the user typed.

### Login challenge

11. When `TwoFactorEnabled`, a successful password check returns a **challenge**, not
    tokens. No access or refresh token is minted at this point.
12. The challenge token is a short-lived, single-purpose, signed artefact. It is **not**
    an access token: it carries no permissions and cannot call business endpoints.
13. The challenge is consumed on first successful verification and cannot be replayed.
14. A failed verification increments the account's normal lockout counter. MFA is not a
    way to brute-force past the existing lockout.
15. A challenge expires in 5 minutes (`SecurityOptions.TwoFactorChallengeMinutes`).
16. Only the *first* successful MFA challenge after password verification mints tokens.
    Repeat challenges for the same login are refused.

### Sessions

17. A session row is created on every successful login, carrying a device label derived
    from the user agent, the client IP, and the last-seen timestamp.
18. `revoke-all` revokes **every active refresh-token family** for the user, in the
    tenant scope. The caller is included: "sign out everywhere" includes this device.
19. Revoking a single session revokes that session's refresh-token family only.
20. Sessions are read-only projections. There is no separate session lifecycle; they
    observe the refresh-token families that already exist.

## Screens (Flutter)

- `/login/two-factor` — `TwoFactorVerifyPage`. Numeric keypad (reuse the M9.2b
  `PinPad` widget for visual consistency), a "use a recovery code" toggle that switches
  the input to free text, inline error, resend-free (no SMS involved), 5:00 countdown
  shown to the user, cancel back to login.
- `/settings/two-factor` — `TwoFactorSetupPage`. Three states driven by `MfaStatus`:
  not enrolled (explainer + "Turn on"), pending (QR + manual secret + confirm field),
  active (status + recovery codes list with a copy button + disable).
- `/settings/sessions` — `SessionsPage`. Device list, each row with label/last-seen and a
  revoke action; a destructive "Sign out everywhere" button in the app bar.
- New sealed `AuthNeedsTwoFactor(email, challengeToken)` state in `AuthController`,
  routed from `journeyRedirect`.
- Settings gains a "Security" section between Profile and Notifications.

## API (backend)

Unauthenticated (rate-limited `auth`):

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/login` | *(existing)* | `LoginResult` — now a **discriminated** payload |
| POST | `/api/v1/auth/mfa/verify` | `{ challengeToken, code }` | `AuthResponse` or `TwoFactorChallengeDto` |

Authenticated (permission-free — a user may always inspect their own security):

| Method | Path | Permission |
| --- | --- | --- |
| GET | `/api/v1/auth/mfa/status` | authenticated |
| POST | `/api/v1/auth/mfa/setup` | authenticated |
| POST | `/api/v1/auth/mfa/confirm` | authenticated |
| POST | `/api/v1/auth/mfa/disable` | authenticated |
| POST | `/api/v1/auth/mfa/recovery-codes` | authenticated |
| GET | `/api/v1/auth/sessions` | authenticated |
| DELETE | `/api/v1/auth/sessions/{id}` | authenticated |
| POST | `/api/v1/auth/sessions/revoke-all` | authenticated |

These are **self-service and permission-free by design** — requiring `Security.Manage`
to view your own devices would let a lockout strand an owner. The same rule already
applies to `GET /api/v1/billing/subscription` (M13.1).

### Login contract change (breaking)

`LoginCommand` currently returns `AuthResponse`. It must now return a discriminated
result, because "wrong password" (401), "unverified" (403 `AccountNotVerified`) and
"needs second factor" (200 with a challenge) are three different outcomes that the
client must route differently.

```csharp
public sealed record LoginResponse(
    string Status,                 // "authenticated" | "two_factor_required"
    AuthResponse? Tokens,          // present when Status == "authenticated"
    string? ChallengeToken,        // present when Status == "two_factor_required"
    string? Email);                // account email, so the client can resume the challenge
```

`Status` is a string discriminator, matching the platform's existing convention of
serializing enums as numbers/strings deliberately — no `JsonStringEnumConverter` is
registered anywhere, so this stays an explicit string rather than an enum.

The Flutter repository must be updated in the same change. There is no compatibility
shim: this is a pre-1.0 product with a single client.

## Database

Migration `AddTwoFactorAndSessions`:

- `Users` — `TwoFactorEnabled` (bool, default false, NOT NULL),
  `TwoFactorSecret` (string, max 128, nullable), `TwoFactorPendingSecret` (string, max 128,
  nullable), `TwoFactorEnabledAt` (timestamptz, nullable)
- `TwoFactorRecoveryCodes` (new table) — Id, TenantId, UserId, CodeHash (128),
  CreatedAt, UsedAt (nullable); index on `(TenantId, UserId)`, index on `CodeHash`

**No `AuthSessions` table.** Sessions are projected from `RefreshTokens` + a
`DeviceLabel`/`IpAddress`/`UserAgent` triple captured on the refresh token. A separate
table would duplicate the refresh-token lifecycle and risk the two disagreeing.

> Correction to the original plan: this slice initially proposed an `AuthSession`
> entity. On inspection, `RefreshToken` already *is* the session — it has `UserId`,
> `TenantId`, `RevokedAt`, and `FamilyId`. Adding a parallel table would create a
> second source of truth for "is this device still signed in". The projection is the
> correct design.

`TwoFactorSecret` is stored base32-encoded but is a **shared secret at rest**. It is
encrypted with the same AES key the platform uses for other secrets (verify what
`Directory.Build.props` / `appsettings` already provides before introducing a new
mechanism — do not add a second crypto scheme).

Table names added to `TableNames.Identity`: `TwoFactorRecoveryCodes`.

## Validation

- TOTP code: exactly 6 numeric characters, digits only after trimming.
- Recovery code: trimmed, case-insensitive, matched by hash.
- Challenge token: non-empty, must parse and not be expired.
- Session id: must be a parseable Guid **and** belong to the caller, else 404.
- DRF window: accept ±1 step (30 s each side) to tolerate device clock drift.

## Permissions

None new. Self-service endpoints are permission-free; enforcement is "is this row yours".

`PermissionNames` is untouched, so no re-seeding is required and no existing role
changes. This is deliberate — adding a permission here would mean re-granting it to
existing tenants, and the owner-lockout problem above argues against it.

## Events

New: `UserTwoFactorEnabledEvent`, `UserTwoFactorDisabledEvent`, `UserRecoveryCodesRegeneratedEvent`.

Consumed by `IdentityActivityFeedHandler` (which already handles the 9 identity events)
so the security change shows in the owner-facing activity feed. Nothing else consumes
them — no module needs to react to a factor being turned on.

## Reports

None. This slice adds no business data.

## Tests

**Backend unit**
- `TwoFactorService`: code generate/verify round-trip, wrong code rejected, ±1 step
  window accepted, expired challenge rejected, malformed base32 secret rejected.
- Recovery codes: 10 generated, all distinct, hash matches, single-use enforced,
  regeneration revokes the prior batch.
- `User.EnableTwoFactor/DisableTwoFactor`: flags and secret fields move together,
  no-op when unchanged, domain events raised.

**Backend integration**
- Enrol → confirm → login returns `two_factor_required` and **no** tokens.
- Verify with a valid code returns the same `AuthResponse` shape as plain login.
- Verify with a used recovery code fails the second time.
- Challenge replay after success fails.
- `revoke-all` invalidates every refresh family; a subsequent refresh 401s.
- Revoking another user's session returns 404 (tenant + ownership isolation).
- Tenant isolation: user A cannot read or revoke user B's sessions.
- Wrong MFA code increments lockout and eventually locks the account.

**Flutter**
- `auth_controller_journey_test`: `two_factor_required` routes to `/login/two-factor`;
  a challenge failure stays on the page; success clears the challenge; cancel returns
  to login.
- `mfa_controller_test`: status → setup → confirm → active transitions; recovery-code
  copy payload; disable requires a code.
- **Regression (the important one):** M9.2's silent offline fallback still works. The
  offline path must never attempt MFA, because there is no server to ask.
- Widget test for `SessionsPage` revoke + revoke-all.
- `api_client_test`: 401 mapping unaffected by the new discriminator.

## Offline & sync

**MFA is explicitly not available offline and must not block offline.** Offline unlock
continues to use the device-bound biometric/PIN path only. No sync-queue entries, no
`TwoFactor` tables in Drift.

Sessions likewise have no offline story; the page shows the last known list and an
honest "can't refresh right now" state rather than pretending.

## Future improvements

- SMS OTP as an alternative second factor (needs gateway + cost model).
- Passkeys / WebAuthn — the correct long-term answer for cheap Android, deferred
  because it needs a real authenticator flow we cannot test on the hardware here.
- New-device email alert on first login from an unseen device.
- Per-role MFA enforcement (currently tenant policy + opt-in).
- Session "last active" in the audit log, not just the sessions page.
