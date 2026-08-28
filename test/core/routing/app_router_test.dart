import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/core/routing/app_router.dart';
import 'package:business_management_system/features/auth/application/auth_controller.dart';
import 'package:business_management_system/features/auth/domain/session.dart';
import 'package:business_management_system/features/workspace/application/workspace_controller.dart';
import 'package:business_management_system/features/workspace/domain/workspace.dart';

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

Workspace workspace(String id) => Workspace(
      id: id,
      name: 'Biz $id',
      currency: 'TZS',
      countryCode: 'TZ',
      businessType: null,
      onboardingComplete: false,
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
          journeyRedirect(auth: auth, workspace: const WorkspaceLoading(), path: path),
          Routes.verifyEmail,
        );
      }
    });

    test('authenticated + loading/failure parks on splash', () {
      for (final workspace in [
        const WorkspaceLoading(),
        const WorkspaceFailure('network down'),
      ]) {
        expect(
          journeyRedirect(auth: authed(), workspace: workspace, path: Routes.home),
          Routes.splash,
        );
        expect(
          journeyRedirect(auth: authed(), workspace: workspace, path: Routes.splash),
          isNull,
        );
      }
    });

    test('authenticated + empty goes to zero-workspace, allows create-business',
        () {
      const workspaceState = WorkspaceEmpty();
      expect(
        journeyRedirect(auth: authed(), workspace: workspaceState, path: Routes.home),
        Routes.zeroWorkspace,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.createBusiness),
        isNull,
      );
      expect(
        journeyRedirect(
            auth: authed(), workspace: workspaceState, path: Routes.zeroWorkspace),
        isNull,
      );
    });

    test('ready without selection is pinned to the picker', () {
      final workspaceState = WorkspaceReady(workspaces: [workspace('a')]);
      expect(
        journeyRedirect(auth: authed(), workspace: workspaceState, path: Routes.home),
        Routes.picker,
      );
      expect(
        journeyRedirect(auth: authed(), workspace: workspaceState, path: Routes.picker),
        isNull,
      );
    });

    test('ready with selection enters the app and blocks journey screens', () {
      final workspaceState = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      expect(
        journeyRedirect(auth: authed(), workspace: workspaceState, path: Routes.home),
        isNull,
      );
      expect(
        journeyRedirect(auth: authed(), workspace: workspaceState, path: Routes.picker),
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
          journeyRedirect(auth: authed(), workspace: workspaceState, path: path),
          Routes.home,
        );
      }
    });

    test('product screens are reachable only inside a selected business', () {
      final selected = WorkspaceReady(
        workspaces: [workspace('a')],
        selected: workspace('a'),
      );
      final unselected = WorkspaceReady(workspaces: [workspace('a')]);

      expect(
        journeyRedirect(auth: authed(), workspace: selected, path: '/products/new'),
        isNull,
      );
      expect(
        journeyRedirect(auth: authed(), workspace: selected, path: '/products/p1/edit'),
        isNull,
      );
      // No business chosen yet — product work waits for the picker.
      expect(
        journeyRedirect(auth: authed(), workspace: unselected, path: '/products/new'),
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
}
