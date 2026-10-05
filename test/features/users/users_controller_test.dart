import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/roles/data/role_models.dart';
import 'package:jolinx_app/features/users/data/user_models.dart';
import 'package:jolinx_app/features/users/data/user_providers.dart';

class FakeUserRepository implements UserRepository {
  PagedUsers? pageToReturn;
  Object? errorToThrow;
  Map<String, dynamic>? lastCreateBody;
  String? lastUpdateId;
  Map<String, dynamic>? lastUpdateBody;

  @override
  Future<PagedUsers> list({int page = 1, int pageSize = 50}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return pageToReturn ?? const PagedUsers(items: [], total: 0);
  }

  @override
  Future<IdentityUser> getById(String id) async {
    if (errorToThrow != null) throw errorToThrow!;
    return IdentityUser(
      id: id,
      email: '$id@test.com',
      fullName: 'User',
      isActive: true,
      emailVerified: true,
      isLockedOut: false,
      roleIds: const [],
      branchIds: const [],
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<void> create(Map<String, dynamic> body) async {
    lastCreateBody = body;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> body) async {
    lastUpdateId = id;
    lastUpdateBody = body;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> setStatus(String id, bool isActive) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> setRoles(String userId, List<String> roleIds) async {}

  @override
  Future<List<Role>> roles() async => [];
}

void main() {
  group('UsersController', () {
    test('initial state is Loading', () {
      final repository = FakeUserRepository();
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);

      expect(controller.state, isA<UsersLoading>());
    });

    test('load() transitions to Loaded', () async {
      final repository = FakeUserRepository()
        ..pageToReturn = PagedUsers(
          items: [
            IdentityUser(
              id: 'u1',
              email: 'u1@test.com',
              fullName: 'Alice',
              isActive: true,
              emailVerified: true,
              isLockedOut: false,
              roleIds: const [],
              branchIds: const [],
              createdAt: DateTime(2026),
            ),
            IdentityUser(
              id: 'u2',
              email: 'u2@test.com',
              fullName: 'Bob',
              isActive: true,
              emailVerified: true,
              isLockedOut: false,
              roleIds: const [],
              branchIds: const [],
              createdAt: DateTime(2026),
            ),
          ],
          total: 2,
        );
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);

      await controller.load();

      final state = controller.state as UsersLoaded;
      expect(state.items, hasLength(2));
      expect(state.items[0].fullName, 'Alice');
      expect(state.total, 2);
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeUserRepository()
        ..errorToThrow = ServerException('Cannot load users');
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);

      await controller.load();

      final state = controller.state as UsersFailure;
      expect(state.message, 'Cannot load users');
    });

    test('create() calls repository then reloads', () async {
      final repository = FakeUserRepository()
        ..pageToReturn = PagedUsers(
          items: [
            IdentityUser(
              id: 'u1',
              email: 'u1@test.com',
              fullName: 'New',
              isActive: true,
              emailVerified: true,
              isLockedOut: false,
              roleIds: const [],
              branchIds: const [],
              createdAt: DateTime(2026),
            ),
          ],
          total: 1,
        );
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);

      await controller.create({'name': 'New', 'email': 'new@test.com'});

      expect(repository.lastCreateBody!['name'], 'New');
      final state = controller.state as UsersLoaded;
      expect(state.items, hasLength(1));
      expect(state.items[0].fullName, 'New');
    });

    test('update() calls repository then reloads', () async {
      final repository = FakeUserRepository()
        ..pageToReturn = PagedUsers(
          items: [
            IdentityUser(
              id: 'u1',
              email: 'u1@test.com',
              fullName: 'Updated',
              isActive: true,
              emailVerified: true,
              isLockedOut: false,
              roleIds: const [],
              branchIds: const [],
              createdAt: DateTime(2026),
            ),
          ],
          total: 1,
        );
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);

      await controller.update('u1', {'name': 'Updated'});

      expect(repository.lastUpdateId, 'u1');
      expect(repository.lastUpdateBody!['name'], 'Updated');
      final state = controller.state as UsersLoaded;
      expect(state.items[0].fullName, 'Updated');
    });

    test('reset() transitions to Loading', () async {
      final repository = FakeUserRepository()
        ..pageToReturn = PagedUsers(
          items: [
            IdentityUser(
              id: 'u1',
              email: 'u1@test.com',
              fullName: 'User',
              isActive: true,
              emailVerified: true,
              isLockedOut: false,
              roleIds: const [],
              branchIds: const [],
              createdAt: DateTime(2026),
            ),
          ],
          total: 1,
        );
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(usersControllerProvider.notifier);
      await controller.load();
      expect(controller.state, isA<UsersLoaded>());

      controller.reset();

      expect(controller.state, isA<UsersLoading>());
    });
  });
}
