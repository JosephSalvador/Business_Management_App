import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/role_models.dart';

sealed class RolesState {
  const RolesState();
}

class RolesLoading extends RolesState {
  const RolesLoading();
}

class RolesLoaded extends RolesState {
  const RolesLoaded({required this.items});

  final List<Role> items;
}

class RolesFailure extends RolesState {
  const RolesFailure(this.message);

  final String message;
}

class RolesController extends Notifier<RolesState> {
  @override
  RolesState build() => const RolesLoading();

  RoleRepository get _repository => ref.read(roleRepositoryProvider);

  Future<void> load() async {
    state = const RolesLoading();
    try {
      final items = await _repository.list();
      state = RolesLoaded(items: items);
    } on AppException catch (error) {
      state = RolesFailure(error.message);
    }
  }

  Future<void> create({
    required String name,
    String? description,
    List<String>? permissions,
  }) async {
    final role = await _repository.create(name: name, description: description);
    if (permissions != null && permissions.isNotEmpty) {
      await _repository.setRolePermissions(role.id, permissions);
    }
    await load();
  }

  Future<void> update(
    String id, {
    required String name,
    String? description,
    List<String>? permissions,
  }) async {
    await _repository.update(id, name: name, description: description);
    if (permissions != null) {
      await _repository.setRolePermissions(id, permissions);
    }
    await load();
  }

  Future<void> setPermissions(String id, List<String> permissions) async {
    await _repository.setRolePermissions(id, permissions);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }

  void reset() {
    state = const RolesLoading();
  }
}
