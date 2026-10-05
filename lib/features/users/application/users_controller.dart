import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/user_models.dart';

sealed class UsersState {
  const UsersState();
}

class UsersLoading extends UsersState {
  const UsersLoading();
}

class UsersLoaded extends UsersState {
  const UsersLoaded({required this.items, required this.total});

  final List<IdentityUser> items;
  final int total;
}

class UsersFailure extends UsersState {
  const UsersFailure(this.message);

  final String message;
}

class UsersController extends Notifier<UsersState> {
  @override
  UsersState build() => const UsersLoading();

  UserRepository get _repository => ref.read(userRepositoryProvider);

  Future<void> load() async {
    state = const UsersLoading();
    try {
      final page = await _repository.list();
      state = UsersLoaded(items: page.items, total: page.total);
    } on AppException catch (error) {
      state = UsersFailure(error.message);
    }
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _repository.create(body);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _repository.update(id, body);
    await load();
  }

  Future<void> toggleStatus(String id, bool isActive) async {
    await _repository.setStatus(id, isActive);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }

  void reset() {
    state = const UsersLoading();
  }
}
