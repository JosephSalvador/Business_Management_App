import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/settings/application/settings_controller.dart';
import 'package:jolinx_app/features/settings/data/organization_repository.dart';
import 'package:jolinx_app/features/settings/data/organization_providers.dart';

class FakeOrganizationRepository implements OrganizationRepository {
  Organization? orgToReturn;
  Object? errorToThrow;
  Map<String, dynamic>? lastUpdateBody;

  @override
  Future<Organization> get() async {
    if (errorToThrow != null) throw errorToThrow!;
    return orgToReturn ?? const Organization();
  }

  @override
  Future<Organization> update(Map<String, dynamic> body) async {
    lastUpdateBody = body;
    if (errorToThrow != null) throw errorToThrow!;
    return orgToReturn ?? const Organization();
  }
}

void main() {
  group('SettingsController', () {
    test('initial state is Loading', () {
      final repository = FakeOrganizationRepository();
      final container = ProviderContainer(overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      expect(controller.state, isA<SettingsLoading>());
    });

    test('load() transitions to Loaded with organization', () async {
      final repository = FakeOrganizationRepository()
        ..orgToReturn = const Organization(
          name: 'JolinX Ltd',
          email: 'info@jolinx.co.tz',
          currency: 'TZS',
        );
      final container = ProviderContainer(overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as SettingsLoaded;
      expect(state.organization.name, 'JolinX Ltd');
      expect(state.organization.email, 'info@jolinx.co.tz');
      expect(state.organization.currency, 'TZS');
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeOrganizationRepository()
        ..errorToThrow = ServerException('Cannot reach server');
      final container = ProviderContainer(overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as SettingsFailure;
      expect(state.message, 'Cannot reach server');
    });

    test('updateOrganization() calls repository then reloads', () async {
      final repository = FakeOrganizationRepository()
        ..orgToReturn = const Organization(name: 'Updated');
      final container = ProviderContainer(overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateOrganization({'name': 'Updated'});

      expect(repository.lastUpdateBody, {'name': 'Updated'});
      final state = controller.state as SettingsLoaded;
      expect(state.organization.name, 'Updated');
    });

    test('updateOrganization() transitions to Failure on error', () async {
      final repository = FakeOrganizationRepository()
        ..errorToThrow = ServerException('Update failed');
      final container = ProviderContainer(overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateOrganization({'name': 'X'});

      final state = controller.state as SettingsFailure;
      expect(state.message, 'Update failed');
    });
  });
}
