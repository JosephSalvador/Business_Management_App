import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/profile/data/profile_providers.dart';

class FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? loadError;
  int getCallCount = 0;
  int updateCallCount = 0;
  int changePasswordCallCount = 0;
  String? lastFullName;
  String? lastPhone;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  Future<UserProfile> get() async {
    getCallCount++;
    if (loadError != null) throw loadError!;
    return profileToReturn ??
        const UserProfile(
          id: 'u1',
          fullName: 'Juma',
          email: 'juma@test.co.tz',
          phone: '+255712345678',
          tenantName: 'Acme Ltd',
          roleNames: ['Admin'],
          permissions: [],
        );
  }

  @override
  Future<UserProfile> updateProfile({String? fullName, String? phone}) async {
    updateCallCount++;
    lastFullName = fullName;
    lastPhone = phone;
    return UserProfile(
      id: 'u1',
      fullName: fullName ?? 'Juma',
      email: 'juma@test.co.tz',
      phone: phone ?? '+255712345678',
      tenantName: 'Acme Ltd',
      roleNames: const ['Admin'],
      permissions: const [],
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCallCount++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
  }
}

void main() {
  late FakeProfileRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeProfileRepository();
    container = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);
  });

  ProfileController controller() =>
      container.read(profileControllerProvider.notifier);

  group('ProfileController', () {
    test('initial state is Loading', () {
      expect(container.read(profileControllerProvider), isA<ProfileLoading>());
    });

    test('load() transitions to Loaded with profile', () async {
      await controller().load();

      final state = controller().state as ProfileLoaded;
      expect(state.profile.id, 'u1');
      expect(state.profile.fullName, 'Juma');
      expect(fakeRepo.getCallCount, 1);
    });

    test('load() failure transitions to Failure', () async {
      fakeRepo.loadError = ServerException('Server down');

      await controller().load();

      final state = controller().state;
      expect(state, isA<ProfileFailure>());
      expect((state as ProfileFailure).message, 'Server down');
    });

    test('updateProfile() calls repository then reloads', () async {
      await controller().load();
      await controller().updateProfile(
        fullName: 'Juma Updated',
        phone: '+255700000000',
      );

      expect(fakeRepo.updateCallCount, 1);
      expect(fakeRepo.lastFullName, 'Juma Updated');
      expect(fakeRepo.lastPhone, '+255700000000');
      final state = controller().state as ProfileLoaded;
      expect(state.profile.fullName, 'Juma Updated');
    });

    test('changePassword() calls repository', () async {
      await controller().changePassword(
        currentPassword: 'old',
        newPassword: 'new',
      );

      expect(fakeRepo.changePasswordCallCount, 1);
      expect(fakeRepo.lastCurrentPassword, 'old');
      expect(fakeRepo.lastNewPassword, 'new');
    });
  });
}
