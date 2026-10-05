import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/roles/data/role_models.dart';
import 'package:jolinx_app/features/roles/data/role_providers.dart';

class FakeRoleRepository implements RoleRepository {
  List<Role>? listToReturn;
  Object? loadError;
  int listCallCount = 0;
  int createCallCount = 0;
  String? lastCreatedName;
  String? lastCreatedDescription;
  List<String>? lastCreatedPermissions;
  String? lastSetPermissionsRoleId;
  List<List<String>>? lastSetPermissionsValues;

  @override
  Future<List<Role>> list() async {
    listCallCount++;
    if (loadError != null) throw loadError!;
    return listToReturn ?? [];
  }

  @override
  Future<Role> create({required String name, String? description}) async {
    createCallCount++;
    lastCreatedName = name;
    lastCreatedDescription = description;
    return Role(
      id: 'r-new',
      name: name,
      description: description,
      isSystem: false,
      permissionNames: const [],
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<Role> getById(String id) async => Role(
        id: id,
        name: 'Role',
        isSystem: false,
        permissionNames: const [],
        createdAt: DateTime(2026),
      );

  @override
  Future<void> update(String id,
      {required String name, String? description}) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Permission>> permissions() async => [];

  @override
  Future<List<String>> rolePermissions(String roleId) async => [];

  @override
  Future<void> setRolePermissions(
      String roleId, List<String> permissions) async {
    lastSetPermissionsRoleId = roleId;
    lastSetPermissionsValues ??= [];
    lastSetPermissionsValues!.add(permissions);
  }
}

void main() {
  late FakeRoleRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeRoleRepository();
    container = ProviderContainer(overrides: [
      roleRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);
  });

  RolesController controller() =>
      container.read(rolesControllerProvider.notifier);

  group('RolesController', () {
    test('initial state is Loading', () {
      expect(container.read(rolesControllerProvider), isA<RolesLoading>());
    });

    test('load() transitions to Loaded', () async {
      fakeRepo.listToReturn = [
        Role(
          id: 'r1',
          name: 'Admin',
          isSystem: false,
          permissionNames: const [],
          createdAt: DateTime(2026),
        ),
        Role(
          id: 'r2',
          name: 'Viewer',
          isSystem: false,
          permissionNames: const [],
          createdAt: DateTime(2026),
        ),
      ];

      await controller().load();

      final state = controller().state as RolesLoaded;
      expect(state.items.length, 2);
      expect(fakeRepo.listCallCount, 1);
    });

    test('load() failure transitions to Failure', () async {
      fakeRepo.loadError = ServerException('Connection refused');

      await controller().load();

      final state = controller().state;
      expect(state, isA<RolesFailure>());
      expect((state as RolesFailure).message, 'Connection refused');
    });

    test('create() calls repository then reloads', () async {
      fakeRepo.listToReturn = [
        Role(
          id: 'r-new',
          name: 'Editor',
          isSystem: false,
          permissionNames: const [],
          createdAt: DateTime(2026),
        ),
      ];

      await controller().create(
        name: 'Editor',
        description: 'Can edit',
        permissions: ['read'],
      );

      expect(fakeRepo.createCallCount, 1);
      expect(fakeRepo.lastCreatedName, 'Editor');
      expect(fakeRepo.lastCreatedDescription, 'Can edit');
      expect(fakeRepo.listCallCount, 1);
      final state = controller().state as RolesLoaded;
      expect(state.items.first.name, 'Editor');
    });

    test('setPermissions() updates a system role then reloads', () async {
      fakeRepo.listToReturn = [
        Role(
          id: 'r-admin',
          name: 'Administrator',
          isSystem: true,
          permissionNames: const ['Users.View'],
          createdAt: DateTime(2026),
        ),
      ];

      await controller().setPermissions('r-admin', ['Users.View']);

      expect(fakeRepo.lastSetPermissionsRoleId, 'r-admin');
      expect(fakeRepo.lastSetPermissionsValues, [
        ['Users.View'],
      ]);
      expect(fakeRepo.listCallCount, 1);
    });

    test('reset() returns to Loading', () async {
      fakeRepo.listToReturn = [
        Role(
          id: 'r1',
          name: 'Admin',
          isSystem: false,
          permissionNames: const [],
          createdAt: DateTime(2026),
        ),
      ];
      await controller().load();
      expect(controller().state, isA<RolesLoaded>());

      controller().reset();

      expect(controller().state, isA<RolesLoading>());
    });
  });
}
