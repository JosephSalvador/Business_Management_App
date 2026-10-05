import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/organization_repository.dart';

sealed class SettingsState {
  const SettingsState();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded({required this.organization});

  final Organization organization;
}

class SettingsFailure extends SettingsState {
  const SettingsFailure(this.message);

  final String message;
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(load);
    return const SettingsLoading();
  }

  OrganizationRepository get _repository =>
      ref.read(organizationRepositoryProvider);

  Future<void> load() async {
    state = const SettingsLoading();
    try {
      final organization = await _repository.get();
      state = SettingsLoaded(organization: organization);
    } on AppException catch (error) {
      state = SettingsFailure(error.message);
    }
  }

  Future<void> updateOrganization(Map<String, dynamic> body) async {
    try {
      await _repository.update(body);
    } on AppException catch (error) {
      state = SettingsFailure(error.message);
      return;
    }
    await load();
  }
}
