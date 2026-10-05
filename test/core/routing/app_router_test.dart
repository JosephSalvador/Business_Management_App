import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/router.dart';
import 'package:jolinx_app/features/authentication/application/auth_controller.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';
import 'package:jolinx_app/features/billing/domain/billing.dart';
import 'package:jolinx_app/features/onboarding/application/workspace_controller.dart';
import 'package:jolinx_app/features/onboarding/domain/workspace.dart';

AuthAuthenticated authed() => AuthAuthenticated(Session(
      user: const AuthUser(
        id: 'u1',
        tenantId: 't1',
        email: 'owner@test.local',
        fullName: 'Owner',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: [],
      ),
      accessTokenExpiresAt: DateTime.now().toUtc().add(
            const Duration(minutes: 15),
          ),
    ));

Workspace workspace(String id, {bool onboardingComplete = true}) => Workspace(
      id: id,
      name: 'Biz $id',
      currency: 'TZS',
      countryCode: 'TZ',
      businessType: null,
      onboardingComplete: onboardingComplete,
      roles: const ['Administrator'],
    );

void main() {
  group('journeyRedirect — deterministic routing decisions', () {
    test('bootstrap waits on splash', () {
      for (final path in [Routes.login, Routes.home, Routes.verifyEmail]) {
        expect(
          journeyRedirect(
            auth: const AuthUnknown(),
            workspace: const WorkspaceLoading(),
            path: path,
          ),
          Routes.splash,
        );
      }
      expect(
        journeyRedirect(
          auth: const AuthUnknown(),
          workspace: const WorkspaceLoading(),
          path: Routes.splash,
        ),
        isNull,
      );
    });

    test('unauthenticated users are pinned to login/register', () {
      expect(
        journeyRedirect(
          auth: const AuthUnauthenticated(),
          workspace: const WorkspaceLoading(),
          path: Routes.home,
        ),
        Routes.login,
      );
      expect(
        journeyRedirect(
          auth: const AuthUnauthenticated(),
          workspace: const WorkspaceLoading(),
          path: Routes.register,
        ),
        isNull,
      );
      // Regression (2026-08-24): an unauthenticated user on the splash route
      // must be MOVED to login — treating splash as "allowed" parked the
      // whole journey on the splash spinner forever.
      expect(
        journeyRedirect(
          auth: const AuthUnauthenticated(),
          workspace: const WorkspaceLoading(),
          path: Routes.splash,
        ),
        Routes.login,
      );
    });

    test('password recovery screens are public', () {
      for (final path in [
        Routes.forgotPassword,
        Routes.resetPassword,
        Routes.terms,
      ]) {
        expect(
          journeyRedirect(
            auth: const AuthUnauthenticated(),
            workspace: const WorkspaceLoading(),
            path: path,
          ),
          isNull,
          reason: '$path should be reachable without a session',
        );
      }
    });

    test('pending verification is pinned to the verify screen', () {
      const auth = AuthNeedsVerification(email: 'o@t.l');
      expect(
        journeyRedirect(
          auth: auth,
          workspace: const WorkspaceLoading(),
          path: Routes.verifyEmail,
        ),
        isNull,
      );
      for (final path in [Routes.login, Routes.home, Routes.picker]) {
        expect(
          journeyRedirect(
              auth: auth, workspace: const WorkspaceLoading(), path: path),
          Routes.verifyEmail,
        );
      }
    });

    test('a pending second factor blocks every screen but its own', () {
      const auth = AuthNeedsTwoFactor(challengeToken: 'c1', email: 'o@t.l');
      expect(
        journeyRedirect(
          auth: auth,
          workspace: const WorkspaceLoading(),
          path: Routes.twoFactor,
        ),
        isNull,
      );
      // No token has been issued yet, so nothing behind the challenge is reachable.
      for (final path in [
        Routes.login,
        Routes.home,
        Routes.picker,
        Routes.pos,
        Routes.verifyEmail,
      ]) {
        expect(
          journeyRedirect(
              auth: auth, workspace: const WorkspaceLoading(), path: path),
          Routes.twoFactor,
          reason: '$path must not be reachable before the second factor',
        );
      }
    });

    test('a pending second factor is pushed away from an authenticated screen',
        () {
      // Covers the upgrade case: a session that was live before MFA was turned
      // on must not keep rendering app screens while a challenge is outstanding.
      const auth = AuthNeedsTwoFactor(challengeToken: 'c1', email: 'o@t.l');
      expect(
        journeyRedirect(
          auth: auth,
          workspace: const WorkspaceReady(workspaces: []),
          path: Routes.home,
        ),
        Routes.twoFactor,
      );
    });

    test('authenticated + loading/failure parks on splash', () {
      for (final workspace in [
        const WorkspaceLoading(),
        const WorkspaceFailure('network down'),
      ]) {
        expect(
          journeyRedirect(
              auth: authed(), workspace: workspace, path: Routes.home),
          Routes.splash,
        );
        expect(
          journeyRedirect(
              auth: authed(), workspace: workspace, path: Routes.splash),
          isNull,
        );
      }
    });

    test('authenticated + empty goes to zero-workspace, allows create-business',
        () {
      const workspaceState = WorkspaceEmpty();
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.home),
        Routes.zeroWorkspace,
      );
      expect(
        journeyRedirect(
            auth: authed(),
            workspace: workspaceState,
            path: Routes.createBusiness),
        isNull,
      );
      expect(
        journeyRedirect(
            auth: authed(),
            workspace: workspaceState,
            path: Routes.zeroWorkspace),
        isNull,
      );
    });

    test('ready without selection is pinned to the picker', () {
      final workspaceState = WorkspaceReady(workspaces: [workspace('a')]);
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.home),
        Routes.picker,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.picker),
        isNull,
      );
    });

    test('selection with incomplete onboarding is pinned to business setup',
        () {
      final workspaceState = WorkspaceReady(
        workspaces: [workspace('a', onboardingComplete: false)],
        selected: workspace('a', onboardingComplete: false),
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.home),
        Routes.createBusiness,
      );
      expect(
        journeyRedirect(
            auth: authed(),
            workspace: workspaceState,
            path: Routes.createBusiness),
        isNull,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.setup),
        isNull,
      );
    });

    test('ready with selection enters the app and blocks journey screens', () {
      final workspaceState = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.home),
        isNull,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.picker),
        isNull,
      );
      for (final path in [
        Routes.login,
        Routes.register,
        Routes.verifyEmail,
        Routes.zeroWorkspace,
        Routes.createBusiness,
        Routes.splash,
      ]) {
        expect(
          journeyRedirect(
              auth: authed(), workspace: workspaceState, path: path),
          Routes.home,
        );
      }
    });

    test('locked sessions are pinned to the lock screen until unlocked', () {
      final auth = AuthLocked(authed().session);
      for (final path in [
        Routes.home,
        Routes.pos,
        Routes.login,
        Routes.register,
        Routes.picker,
        Routes.splash,
      ]) {
        expect(
          journeyRedirect(
            auth: auth,
            workspace: const WorkspaceLoading(),
            path: path,
          ),
          Routes.lock,
          reason: path,
        );
      }
      expect(
        journeyRedirect(
          auth: auth,
          workspace: const WorkspaceLoading(),
          path: Routes.lock,
        ),
        isNull,
      );
    });

    test('an unlocked user on /lock is taken straight back into the app', () {
      final ready = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      expect(
        journeyRedirect(auth: authed(), workspace: ready, path: Routes.lock),
        Routes.home,
      );
      final loading = const WorkspaceLoading();
      expect(
        journeyRedirect(auth: authed(), workspace: loading, path: Routes.lock),
        Routes.splash,
      );
    });

    test('product screens are reachable only inside a selected business', () {
      final selected = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      final unselected = WorkspaceReady(workspaces: [workspace('a')]);

      expect(
        journeyRedirect(
            auth: authed(), workspace: selected, path: '/products/new'),
        isNull,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: selected, path: '/products/p1/edit'),
        isNull,
      );
      // No business chosen yet — product work waits for the picker.
      expect(
        journeyRedirect(
            auth: authed(), workspace: unselected, path: '/products/new'),
        Routes.picker,
      );
      // And never before authentication.
      expect(
        journeyRedirect(
          auth: const AuthUnauthenticated(),
          workspace: const WorkspaceLoading(),
          path: '/products/new',
        ),
        Routes.login,
      );
    });

    test('POS screens are reachable only inside a selected business', () {
      final selected = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      final unselected = WorkspaceReady(workspaces: [workspace('a')]);

      for (final path in [
        Routes.pos,
        Routes.posSuccess,
        Routes.salesHistory,
        Routes.receipt('s1'),
        Routes.saleDetail('s1'),
      ]) {
        expect(
          journeyRedirect(auth: authed(), workspace: selected, path: path),
          isNull,
          reason: path,
        );
        expect(
          journeyRedirect(auth: authed(), workspace: unselected, path: path),
          Routes.picker,
          reason: path,
        );
      }
    });
  });

  group('premiumRouteRedirect — billing-gated route decisions', () {
    AuthAuthenticated authedWithBilling() => AuthAuthenticated(Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@test.local',
            fullName: 'Owner',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['Billing.View'],
          ),
          accessTokenExpiresAt: DateTime.now().toUtc().add(
                const Duration(minutes: 15),
              ),
        ));

    SubscriptionEntitlement entitlementWith(Set<String> keys) =>
        SubscriptionEntitlement(
          status: keys.contains(BillingFeatureKeys.finance)
              ? SubscriptionStatus.active
              : SubscriptionStatus.debt,
          accessLevel: keys.contains(BillingFeatureKeys.finance)
              ? BillingAccessLevel.full
              : BillingAccessLevel.posAndInventory,
          planCode: 'backstop',
          effectiveFeatureKeys: keys,
          nextDueUtc: null,
          hasOpenInvoice: false,
          maxBranches: null,
          maxUsers: null,
          maxProducts: null,
          evaluatedAtUtc: DateTime.utc(2026, 9, 25, 10),
        );

    const backstop = <String>{
      BillingFeatureKeys.pos,
      BillingFeatureKeys.inventory,
    };
    const pro = <String>{
      BillingFeatureKeys.pos,
      BillingFeatureKeys.inventory,
      BillingFeatureKeys.finance,
      BillingFeatureKeys.accounting,
      BillingFeatureKeys.crm,
      BillingFeatureKeys.purchasing,
      BillingFeatureKeys.reports,
    };

    test('fails open before an entitlement is loaded', () {
      for (final key in [
        BillingFeatureKeys.finance,
        BillingFeatureKeys.crm,
        BillingFeatureKeys.purchasing,
      ]) {
        expect(
          premiumRouteRedirect(
              entitlement: null, auth: authed(), featureKey: key),
          isNull,
          reason: key,
        );
      }
    });

    test('a feature the tenant holds proceeds without a redirect', () {
      for (final key in [
        BillingFeatureKeys.finance,
        BillingFeatureKeys.crm,
        BillingFeatureKeys.purchasing,
      ]) {
        expect(
          premiumRouteRedirect(
            entitlement: entitlementWith(pro),
            auth: authed(),
            featureKey: key,
          ),
          isNull,
          reason: key,
        );
      }
    });

    test('debt lock sends a Billing.View session to the billing desk', () {
      for (final key in [
        BillingFeatureKeys.finance,
        BillingFeatureKeys.crm,
        BillingFeatureKeys.purchasing,
      ]) {
        expect(
          premiumRouteRedirect(
            entitlement: entitlementWith(backstop),
            auth: authedWithBilling(),
            featureKey: key,
          ),
          Routes.billing,
          reason: key,
        );
      }
    });

    test('debt lock sends a session without Billing.View back home', () {
      for (final key in [
        BillingFeatureKeys.finance,
        BillingFeatureKeys.crm,
        BillingFeatureKeys.purchasing,
      ]) {
        expect(
          premiumRouteRedirect(
            entitlement: entitlementWith(backstop),
            auth: authed(),
            featureKey: key,
          ),
          Routes.home,
          reason: key,
        );
      }
    });

    test('backstop keys (pos, inventory) never redirect', () {
      expect(
        premiumRouteRedirect(
          entitlement: entitlementWith(backstop),
          auth: authed(),
          featureKey: BillingFeatureKeys.pos,
        ),
        isNull,
      );
      expect(
        premiumRouteRedirect(
          entitlement: entitlementWith(backstop),
          auth: authed(),
          featureKey: BillingFeatureKeys.inventory,
        ),
        isNull,
      );
    });

    test('the billing route itself requires Billing.View', () {
      expect(
        journeyRedirect(
          auth: authed(),
          workspace: WorkspaceReady(
            workspaces: [workspace('a')],
            selected: workspace('a'),
          ),
          path: Routes.billing,
        ),
        isNull,
        reason: 'billing is not a journey screen; its own guard applies',
      );
    });
  });
}
