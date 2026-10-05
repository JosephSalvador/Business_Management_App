# TASKS — MFA & Session Management (Slice M14)

> Spec: `specs/mfa-sessions.md`. Implement one task at a time; run analyzers and tests
> after each; update this file as you go. No code until the spec and this plan are approved.
>
> Commit style: `feat(mfa): ...`, `test(mfa): ...`.
>
> **M15–M20 are planned but NOT approved to start.** See `docs/roadmap-parity-plan.md`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 14a — Domain

- [ ] 001 **`User` two-factor state**: add `TwoFactorEnabled`, `TwoFactorSecret`,
      `TwoFactorPendingSecret`, `TwoFactorEnabledAt` with private setters. Methods
      `StageTwoFactor(encryptedSecret)`, `EnableTwoFactor(encryptedSecret, at)`,
      `DisableTwoFactor()`, `HasPendingTwoFactor`. Idempotent (no event when unchanged).
      New events in `Domain/Events/`.
- [ ] 002 **`TwoFactorRecoveryCode`** entity: `Create(tenantId, userId, codeHash)`,
      `TryConsume()`, `IsUsed`. Unit tests.
- [ ] 003 **Events**: `UserTwoFactorEnabledEvent`, `UserTwoFactorDisabledEvent`,
      `UserRecoveryCodesRegeneratedEvent`.
- [ ] 004 **`AuthConstants`**: `TwoFactorRecoveryCodeCount = 10`, challenge lifetime,
      manual-entry padding constant.

## 14b — Application

- [ ] 005 **`ITotpService` port** in `Application/Ports/IPlatformServices.cs`
      (generate secret, provisioning URI, verify code within a time step).
- [ ] 006 **`ISecretProtector` port** — reuse the platform's existing AES mechanism.
      **Verify what already exists before adding anything** (rule: never duplicate).
- [ ] 007 **`TwoFactorService`** (Application/Services): secret staging, code
      verification with ±1 step, challenge token issue/verify (signed, single-use,
      5-minute TTL, no permissions), recovery-code generation (CSPRNG, 10 distinct)
      and hash matching. Unit tests.
- [ ] 008 **`SecurityOptions` additions**: `TwoFactorChallengeMinutes = 5`,
      `TwoFactorDigits = 6`, `TwoFactorStepSeconds = 30`, `TwoFactorWindow = 1`,
      `TwoFactorRecoveryCodeCount = 10`, `TwoFactorRequiredForOwners = true`.
- [ ] 009 **Repository ports**: `ITwoFactorRecoveryCodeRepository`
      (add/update/remove/list-for-user/consume-attempt) + `IRefreshTokenRepository`
      additions for the session projection (`ListActiveFamiliesAsync`,
      `ListActiveByUserAsync`).
- [ ] 010 **`LoginCommand` contract change**: return `LoginResponse` with the
      `Status` discriminator; when `TwoFactorEnabled` return a challenge and **no**
      tokens. Update `AuthResponse` shape. Unit tests for all four paths
      (ok / bad password / unverified / needs-mfa).
- [ ] 011 **`VerifyTwoFactorCommand`**: validate challenge, accept TOTP **or** recovery
      code, consume, then mint the same tokens + session row a plain login would.
      Wrong code feeds the existing lockout counter.
- [ ] 012 **Enrolment commands**: `SetupTwoFactorCommand`, `ConfirmTwoFactorCommand`,
      `DisableTwoFactorCommand`, `RegenerateRecoveryCodesCommand`. All audit.
- [ ] 013 **Session queries**: `ListMySessionsQuery` (projection), `RevokeSessionCommand`,
      `RevokeAllSessionsCommand`. Revoke-all includes the caller's own device.
- [ ] 014 **Validators**: code format, recovery code length, session id.
- [ ] 015 **`IdentityActivityFeedHandler`**: consume the 3 new events.

## 14c — Infrastructure

- [ ] 016 **EF config**: map the 4 new `User` columns; map `TwoFactorRecoveryCodes`
      with indexes. `TableNames.Identity.TwoFactorRecoveryCodes`.
- [ ] 017 **Migration** `AddTwoFactorAndSessions` — full `Designer.cs` (the project
      requires a non-null `TargetModel`; see the `AddExpenseCategories` lesson).
      Update `BusinessDbContextModelSnapshot`.
- [ ] 018 **Repositories**: EF implementations of 009 + DI registration.
- [ ] 019 **`TotpService`** in Infrastructure using the existing crypto story.
      **Do not add a NuGet package** unless `Directory.Build.props` already permits it.
- [ ] 020 **`SecretProtector`** — reuse existing; only add if none exists.

## 14d — API

- [ ] 021 **Endpoints**: the 8 routes from the spec. `/mfa/*` and `/sessions/*`
      permission-free, `RequireAuthorization()`.
- [ ] 022 **`Program.cs`**: register the new handlers/services.
- [ ] 023 **Swagger**: verify the new endpoints appear and the bearer scheme is usable.

## 14e — Flutter

- [ ] 024 **Models**: `MfaStatus`, `TwoFactorSetup`, `RecoveryCodeBatch`,
      `AuthSession`, `LoginResult` (discriminated).
- [ ] 025 **Repository**: `MfaRepository` (8 calls) + `AuthRepository.login` updated
      for the `Status` discriminator.
- [ ] 026 **`AuthNeedsTwoFactor(email, challengeToken)`** sealed state +
      `journeyRedirect` branch → `/login/two-factor`.
- [ ] 027 **`error_mapper`**: no new status codes needed; keep `AccountNotVerified`
      behaviour intact (M4/Mx regression guard).
- [ ] 028 **`TwoFactorVerifyPage`** reusing the M9.2b `PinPad`; recovery-code toggle;
      5:00 countdown; inline errors; cancel.
- [ ] 029 **`MfaController` + `TwoFactorSetupPage`**: three states, QR render,
      manual-secret fallback, copy-to-clipboard recovery codes, disable-with-code.
- [ ] 030 **`SessionsController` + `SessionsPage`**: list, revoke, revoke-all.
- [ ] 031 **Settings "Security" section** + router entries.
- [ ] 032 **ARB** EN/SW keys, then `flutter gen-l10n`. Edit ARB only — never
      hand-patch `lib/l10n/generated/` (M13.2 lesson).

## 14f — Tests

- [ ] 033 **Backend unit** — see spec "Tests".
- [ ] 034 **Backend integration** — enrol/confirm/login/verify/replay/revoke-all/
      tenant-isolation/lockout.
- [ ] 035 **Flutter** — journey, controller, widget, and the **offline regression**
      (M9.2 silent fallback must still pass).

## 14g — Docs

- [ ] 036 **Swagger/APIStandards** entry for the changed login contract.
- [ ] 037 **`memory/project.md`** — M14 completion note, test counts, verification run.
- [ ] 038 **Changelog** entry.
