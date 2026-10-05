import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.profile});

  final UserProfile profile;
}

class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message);

  final String message;
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileLoading();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  Future<void> load() async {
    state = const ProfileLoading();
    try {
      final profile = await _repository.get();
      state = ProfileLoaded(profile: profile);
    } on AppException catch (error) {
      state = ProfileFailure(error.message);
    }
  }

  Future<void> updateProfile({String? fullName, String? phone}) async {
    try {
      final profile = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
      );
      state = ProfileLoaded(profile: profile);
    } on AppException catch (error) {
      state = ProfileFailure(error.message);
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on AppException {
      rethrow;
    }
  }

  void reset() {
    state = const ProfileLoading();
  }
}
