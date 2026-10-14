# Professional Fast Login & Quick PIN Architecture Plan

## 1. Goal

Upgrade the app's fast-authentication and lock mechanics to match top-tier fintech and POS standards (Square POS, M-Pesa, Revolut, Shopify POS):
1. Fix native Android biometric integration so in-display and physical fingerprint scanners invoke the OS system dialog reliably.
2. Remove silent/forced biometric assumptions — make Quick Login explicitly user-opted.
3. Establish a standard, responsive **4-digit Quick PIN** as the primary fast factor across all platforms (Mobile, Desktop, Web).
4. Integrate biometric hardware (Fingerprint / Face ID) as an optional, native system overlay with automatic prompt on launch.
5. Provide complete user control in the **Security Settings** page (enable/disable, change PIN, toggle biometrics).

---

## 2. Problem Analysis & Root Causes

1. **Android Biometric Crash / Silent Failure:**
   - In `android/app/src/main/kotlin/com/jolinx/app/MainActivity.kt`, the class inherited from `FlutterActivity`.
   - Android's `androidx.biometric.BiometricPrompt` requires `FlutterFragmentActivity`. Without this, platform calls fail silently and the native in-display fingerprint prompt never renders.
2. **Forced Biometric Without Consent:**
   - `AuthRepository._storeOfflineCredentials` automatically called `enableQuickUnlock` upon online login.
   - If the OS reported any enrolled fingerprint, the app forced `FastUnlockPanel` without the user ever requesting biometric login.
3. **Non-Standard UI:**
   - A large custom `FilledButton.tonalIcon` was placed in the middle of the screen instead of triggering the native OS prompt and providing a clean, standard 4-digit PIN pad.

---

## 3. Architecture & Design Specification

### 3.1 Android Platform Integration
- Update `MainActivity.kt`:
  - Inherit from `FlutterFragmentActivity` instead of `FlutterActivity`.
- Update `AndroidManifest.xml`:
  - Ensure `<uses-permission android:name="android.permission.USE_BIOMETRIC" />` is declared.

### 3.2 Secure Storage & Preference Model
Extend `OfflineCredentialStore`:
- `_biometricEnabledKey`: Flag indicating user explicitly enabled biometric login for this app (`isBiometricEnabled()`, `setBiometricEnabled(bool)`).
- `_quickPinEnabledKey`: Flag indicating 4-digit PIN login is active (`isQuickPinEnabled()`, `setQuickPinEnabled(bool)`).
- Ensure PIN validation enforces exactly 4 digits (`RegExp(r'^\d{4}$')`).
- Preserve PBKDF2-SHA256 (100,000 iterations + 32-byte salt) and exponential lockout for brute-force protection.

### 3.3 Post-Login Onboarding ("Set Up Quick PIN")
- After an account logs in with full credentials (email/password), if Quick PIN is not yet configured:
  - Present a clean, non-intrusive sheet: **"Weka PIN ya Kuingia Haraka"**.
  - User chooses a 4-digit PIN with confirmation step.
  - If device supports biometrics (`BiometricAuthGate.isAvailable()` is true), present an opt-in switch: **"Ruhusu pia alama ya kidole au uso"**.
  - Include **"Ruka kwa sasa"** (Skip) option to allow standard password-only access.
  - Saving sets the credentials, enables `quickUnlock`, and establishes device trust.

### 3.4 Modern 4-Digit PIN & Biometric Screen (`LoginPage` & `LockPage`)
- Primary Fast Interface:
  - Displays business branding and personalized greeting (`Habari, {Name}`).
  - 4 PIN indicator dots with smooth filling animation.
  - Tactile, accessible numeric keypad (1–9, biometric action / empty, 0, backspace).
  - Physical keyboard support for desktop / hardware barcode-scanner keyboards.
- Biometric Integration:
  - If biometrics is enabled, automatically trigger the native OS `BiometricPrompt` on appearance so in-display and physical scanners light up immediately.
  - If the prompt is dismissed or fails, the user seamlessly falls back to entering their 4-digit PIN.
  - A biometric icon is available on the keypad to re-trigger the OS prompt on demand.
- Escape Hatch:
  - Text button at the bottom: **"Ingia kwa nenosiri"** / **"Badili mtumiaji"** to switch back to the full identifier & password form.

### 3.5 Security Settings Management (`SecurityPage`)
- Add a dedicated section in `SecurityPage`: **"Ulinzi wa Kifaa hiki (Kuingia Haraka)"**:
  - **PIN ya Haraka:** Status (Imewashwa / Haijawashwa), action to Badili PIN (Change PIN) or Zima PIN (Disable).
  - **Alama ya Kidole / Uso:** Switch toggle to enable/disable biometric unlock.

---

## 4. Implementation Tasks

1. **Platform Fix (Android):**
   - Switch `MainActivity.kt` to `FlutterFragmentActivity`.
   - Update `AndroidManifest.xml` with biometric permissions.
2. **Credential & State Layer:**
   - Update `OfflineCredentialStore` with `biometricEnabled` and `quickPinEnabled` getters/setters.
   - Update `AuthRepository` to decouple password hashing from forced quick unlock.
   - Add controller methods in `AuthController` and `SecurityController` for PIN setup, PIN change, and biometric toggling.
3. **UI Components & Sheets:**
   - Build a professional 4-digit PIN setup sheet (`QuickPinSetupSheet`) with confirmation and optional biometric toggle.
   - Modernize `PinPad` and `FastUnlockPanel` with standard 4-dot indicators and tactile keypad.
4. **Login & Lock Pages:**
   - Wire `LoginPage` to show the modern PIN pad when quick PIN is active, auto-trigger native biometric when enabled, and offer "Sign in with password".
   - Wire `LockPage` with the same professional layout for background/idle recovery.
5. **Security Settings Page:**
   - Add device security controls (PIN management and biometric switch) in `SecurityPage`.
6. **Localization & Polish:**
   - Ensure Swahili and English localization strings are comprehensive and clean.
   - Run tests and code verification.

---

## 5. Definition of Done

- In-display and hardware fingerprint scanners on Android trigger the native system dialog.
- Users are asked to set up a Quick PIN after login with the option to opt-in to biometrics or skip.
- The login screen presents a clean, banking-grade 4-digit PIN pad when Quick PIN is active.
- Biometrics automatically launches the native prompt when enabled, falling back cleanly to PIN if cancelled.
- Users can toggle biometrics and change their PIN anytime in Security Settings.
- `flutter analyze` and tests pass without regressions.
