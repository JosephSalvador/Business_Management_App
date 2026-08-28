import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/features/workspace/application/workspace_controller.dart';
import 'package:business_management_system/features/workspace/data/workspace_repository.dart';
import 'package:business_management_system/features/workspace/domain/workspace.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({this.mineResult = const [], this.mineError});

  List<Workspace> mineResult;
  Object? mineError;
  int loadCalls = 0;
  OnboardingDraft? lastDraft;
  int createCalls = 0;

  @override
  Future<List<Workspace>> mine() async {
    loadCalls++;
    final error = mineError;
    if (error != null) {
      throw error;
    }
    return mineResult;
  }

  @override
  Future<Workspace> completeOnboarding(OnboardingDraft draft) async {
    createCalls++;
    lastDraft = draft;
    const created = Workspace(
      id: 't1',
      name: 'Duka',
      currency: 'TZS',
      countryCode: 'TZ',
      businessType: 'retail',
      onboardingComplete: true,
      roles: ['Administrator'],
    );
    // Mirror the backend: after onboarding the workspace appears in /mine.
    mineResult = [created];
    return created;
  }
}

Workspace workspace(String id, {bool complete = false}) => Workspace(
      id: id,
      name: 'Biz $id',
      currency: 'TZS',
      countryCode: 'TZ',
      businessType: null,
      onboardingComplete: complete,
      roles: const ['Administrator'],
    );

void main() {
  group('WorkspaceController', () {
    test('load with zero workspaces transitions to empty', () async {
      final controller =
          WorkspaceController(FakeWorkspaceRepository(mineResult: []));

      await controller.load();

      expect(controller.state, isA<WorkspaceEmpty>());
    });

    test('load auto-selects the first workspace', () async {
      final controller = WorkspaceController(
        FakeWorkspaceRepository(
            mineResult: [workspace('a'), workspace('b')]),
      );

      await controller.load();

      final ready = controller.state as WorkspaceReady;
      expect(ready.workspaces, hasLength(2));
      expect(ready.selected!.id, 'a');
    });

    test('load failure surfaces a user-facing message', () async {
      final controller = WorkspaceController(
        FakeWorkspaceRepository(mineError: NetworkException()),
      );

      await controller.load();

      expect(controller.state, isA<WorkspaceFailure>());
    });

    test('select only accepts known workspaces', () async {
      final controller = WorkspaceController(
        FakeWorkspaceRepository(
            mineResult: [workspace('a'), workspace('b')]),
      );
      await controller.load();

      controller.select(workspace('unknown'));

      expect((controller.state as WorkspaceReady).selected!.id, 'a');
      controller.select(workspace('b'));
      expect((controller.state as WorkspaceReady).selected!.id, 'b');
    });

    test('createBusiness posts the draft and reloads to ready', () async {
      final repository = FakeWorkspaceRepository(mineResult: []);
      final controller = WorkspaceController(repository);
      await controller.load();
      expect(controller.state, isA<WorkspaceEmpty>());

      await controller.createBusiness(const OnboardingDraft(
        name: ' Duka la Mama ',
        businessType: 'RETAIL',
        countryCode: 'tz',
        currency: ' tzs ',
        contactPhone: ' 0712345678 ',
        taxId: null,
      ));

      expect(repository.createCalls, 1);
      // Body normalisation happens in the repository draft.
      expect(repository.lastDraft!.toBody(), {
        'name': 'Duka la Mama',
        'businessType': 'retail',
        'countryCode': 'TZ',
        'currency': 'TZS',
        'contactPhone': '0712345678',
      });
      final ready = controller.state as WorkspaceReady;
      expect(ready.selected!.onboardingComplete, isTrue);
    });
  });
}
