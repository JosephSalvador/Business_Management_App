import '../../../app/providers.dart';
import '../../authentication/data/auth_providers.dart';
import '../application/settings_controller.dart';
import 'organization_repository.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheDaoProvider),
  ),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
