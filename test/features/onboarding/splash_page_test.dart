import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/features/onboarding/application/workspace_controller.dart';
import 'package:jolinx_app/features/onboarding/presentation/pages/splash_page.dart';

class _FixedWorkspaceController extends WorkspaceController {
  _FixedWorkspaceController(this._initial);

  final WorkspaceState _initial;
  int loadCalls = 0;

  @override
  WorkspaceState build() => _initial;

  @override
  Future<void> load() async {
    loadCalls++;
  }
}

void main() {
  testWidgets('SplashPage animates Rising Growth J logo while loading',
      (tester) async {
    final controller = _FixedWorkspaceController(const WorkspaceLoading());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(
          home: SplashPage(),
        ),
      ),
    );

    expect(find.text('JOLINX'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Advance through the 1450ms choreographed intro animation.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('JOLINX'), findsOneWidget);
  });

  testWidgets('SplashPage renders failure view and triggers retry',
      (tester) async {
    final controller =
        _FixedWorkspaceController(const WorkspaceFailure('Offline error'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(
          home: SplashPage(),
        ),
      ),
    );

    expect(find.text('Hitilafu ya Mtandao'), findsOneWidget);
    expect(find.text('Offline error'), findsOneWidget);

    await tester.tap(find.text('Jaribu tena'));
    await tester.pump();
    expect(controller.loadCalls, 1);
  });
}
