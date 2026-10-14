import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/platform/device_info.dart';
import '../data/notification_providers.dart';
import '../data/notification_repository.dart';

class DeviceRegistrationService {
  DeviceRegistrationService({
    required NotificationRepository repository,
    required DeviceIdentity deviceIdentity,
  })  : _repository = repository,
        _deviceIdentity = deviceIdentity;

  final NotificationRepository _repository;
  final DeviceIdentity _deviceIdentity;

  Future<void> registerDevice({String? fcmToken}) async {
    try {
      final deviceId = await _deviceIdentity.get();
      final platform = kIsWeb
          ? 'web'
          : Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : Platform.isLinux
                      ? 'linux'
                      : Platform.isWindows
                          ? 'windows'
                          : Platform.isMacOS
                              ? 'macos'
                              : 'other';

      await _repository.registerDevice(
        deviceId: deviceId,
        fcmToken: fcmToken ?? 'dev-token-$deviceId',
        platform: platform,
        deviceName: kIsWeb ? 'Web Browser' : Platform.localHostname,
      );
    } catch (_) {
      // Ignored background registration failure
    }
  }

  Future<void> unregisterDevice() async {
    try {
      final deviceId = await _deviceIdentity.get();
      await _repository.unregisterDevice(deviceId);
    } catch (_) {
      // Ignored background cleanup failure
    }
  }
}

final deviceRegistrationServiceProvider = Provider<DeviceRegistrationService>(
  (ref) => DeviceRegistrationService(
    repository: ref.watch(notificationRepositoryProvider),
    deviceIdentity: ref.watch(deviceIdentityProvider),
  ),
);
