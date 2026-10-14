# Senior Multimedia Pro Splash & Background Startup Warmup Architecture Plan

## 1. Vision & Goals

Transform the launch experience of **Jolinx** from a standard mobile app into a premier, world-class fintech operating system (rivaling Linear, Stripe Dashboard, Revolut, and Shopify POS):
1. **Cinema-Grade Motion Design:** Replace standard progress bars and rigid boxes with an organic, kinetic vector emblem choreography featuring specular lighting sweeps, breathing radial aura, and spring-damper physics.
2. **Instant Perceived Performance (< 800ms):** Implement the *Stale-While-Revalidate / Optimistic Hydration* pattern used by top apps — eliminate network blocking on splash by restoring cached workspace and session state in < 25ms.
3. **Zero Boring Spinners:** Remove full-screen blocking wheels; replace them with contextual content-first hydration and subtle status telemetry.
4. **Asynchronous Background Warmup Pipeline:** While the user enjoys the snappy 750ms brand intro or enters their PIN, silently warm up Drift SQLite, local catalog cache, printer connections, and subscription capabilities concurrently.

---

## 2. Multimedia Pro Motion & Visual Choreography (`SplashPage`)

### 2.1 The Emblem & Luminous Canvas
- **Ambient Celestial Aura:** A pulsating multi-stop radial gradient behind the emblem (`Color(0xFF0055D4).withValues(alpha: 0.25)` to `transparent`) that expands gently like a heartbeat.
- **Cobalt/Royal Sapphire Squircle:**
  - Gradient: `[Color(0xFF1E6BFF), Color(0xFF0D47A1), Color(0xFF061A40)]`.
  - Elevation: Layered soft shadows with dynamic ambient glow matching the accent emerald.
- **Specular Glass Gleam:** A custom diagonal specular light sweep (`LinearGradient` with angle $\approx 45^\circ$) that refracts across the squircle badge right as the J arrow locks into place.
- **The "Rising Growth J" Vector Choreography:**
  - **Bar 1 (Short Growth Pillar):** Rises with ease-out spring physics and a subtle emerald top bevel.
  - **Bar 2 (Medium Growth Pillar):** Follows with a staggered delay (offset ~120ms).
  - **The Sweeping J Curve:** Uncoils smoothly along its mathematical bezier arc with a neon-teal comet glow (`#00E5A3` / `#38F9D4`) and pure metallic white core.
  - **The Apex Arrowhead:** Snaps open with spring overshoot (`Curves.easeOutBack`) and an emerald particle flare.
- **Kinetic Wordmark:**
  - **"JOLINX"** title with expanding kerning animation (letter spacing blooming from `1.5` to `3.5`) and smooth opacity fade.
  - Subtitle: *"Simamia biashara yako yote sehemu moja"* (or localized tagline).
- **No Progress Bars:** Remove the clunky `LinearProgressIndicator`. In its place:
  - An ultra-sleek, breathing status pill with micro-telemetry (e.g., *"Inaandaa kituo cha kazi..."* $\to$ *"Tayari"*).
  - If cached data is ready, it smoothly dissolves directly into the app journey without any stalling.

---

## 3. Background Processing Pipeline (The Engineering Architecture)

### 3.1 Two-Phase Startup Architecture

```
═══════════════════════════════════════════════════════════════════════════════════════
Phase 1: INSTANT HYDRATION (< 50ms)           Phase 2: BACKGROUND WARMUP (Non-blocking)
═══════════════════════════════════════════════════════════════════════════════════════
1. Read JWT session from secure storage       1. Silent Token Refresh (/api/v1/auth/refresh)
2. Read cached Workspace from local store     2. Background Workspace Sync (/workspaces/mine)
3. Pre-read active Branch & Currency          3. Local Drift SQLite Catalog prefetch
4. Check Quick PIN / Biometric status         4. Delta Sync Queue Drain (offline sales)
                                              5. Bluetooth Thermal Printer pre-check
                                              6. Subscription Entitlements Refresh
───────────────────────────────────────────── ─────────────────────────────────────────
  ↓                                             ↓
Splash Intro Animation (750ms)                Silently running in background isolates
  ↓                                             ↓
IMMEDIATE REVEAL to Home / POS / Quick PIN    User already browsing products / selling!
═══════════════════════════════════════════════════════════════════════════════════════
```

### 3.2 Optimistic Workspace Hydration
- **Problem:** Currently, `WorkspaceController.load()` calls `GET /api/v1/workspaces/mine` on every start, keeping `WorkspaceLoading` on the splash screen for seconds over slow mobile networks.
- **Solution:** Cache the active `Workspace` in secure storage or local database.
  - On launch, `WorkspaceController` hydrates the cached workspace in < 10ms $\to$ immediately transitions to `WorkspaceReady(selected: cached)`.
  - The splash screen immediately finishes its animation and navigates to `Routes.home`.
  - In the background, `_repository.mine()` verifies and updates the cache without blocking the UI.

### 3.3 Centralized `StartupWarmupService`
- Orchestrates non-blocking background tasks after the first frame:
  - Catalog prefetch (warms Riverpod memory cache).
  - Capabilities & entitlement check.
  - Offline sync engine poll.

---

## 4. Implementation Steps

1. **Step 1: Workspace Local Cache & Optimistic Hydration**
   - Add local workspace caching in `WorkspaceRepository` / `WorkspaceController`.
   - Ensure `WorkspaceReady` hydrates from cache instantly on authenticated launch.
2. **Step 2: Startup Background Pipeline Runner**
   - Create `StartupWarmupService` in `lib/core/services/startup_warmup_service.dart`.
   - Wire it to fire non-blocking tasks on app launch.
3. **Step 3: Senior Multimedia Pro Redesign of `SplashPage`**
   - Upgrade `SplashPage` with specular gleam, kinetic letter-spacing, radial aura glow, refined spring physics, and sleek telemetry status.
   - Remove the linear progress bar.
4. **Step 4: Verification & Polishing**
   - Verify smooth 60/120 FPS animation rendering.
   - Run unit and widget tests to ensure zero regressions in routing and state transitions.

---

## 5. Definition of Done

- Splash screen features high-end kinetic animation with specular sweep, radial aura, and spring physics.
- No full-screen blocking spinners or progress bars.
- Authenticated launch transitions to Home/Quick PIN within ~750–850ms without waiting for HTTP network calls.
- Heavy services (catalog, sync, printer, tokens) process silently in the background.
- Tests pass cleanly.
