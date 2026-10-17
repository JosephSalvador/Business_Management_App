import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native platform bridge for store-bypassing APK installation on Android,
/// and runtime app version queries.
class NativeInstallerService {
  NativeInstallerService._();

  static const _channel = MethodChannel('com.jolinx.app/installer');

  /// Checks if the app currently has permission to install packages on Android.
  /// Always returns true on non-Android platforms.
  static Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final result =
          await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('NativeInstallerService: canRequestPackageInstalls error: $e');
      return true;
    }
  }

  /// Opens the Android system settings screen allowing the user to toggle
  /// "Allow from this source" for Jolinx.
  static Future<bool> openInstallPermissionSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result =
          await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          'NativeInstallerService: openInstallPermissionSettings error: $e');
      return false;
    }
  }

  /// Triggers the native Android Package Installer for the downloaded APK file.
  /// Launches [Intent.ACTION_VIEW] via AndroidX FileProvider.
  static Future<bool> installApk(String filePath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeInstallerService: installApk error: $e');
      return false;
    }
  }

  /// Queries the running native build number and version name.
  static Future<({String versionName, int versionCode})?>
      getAppVersion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getAppVersion');
      if (result != null) {
        final name = (result['versionName'] as String?) ?? '1.0.0';
        final code = (result['versionCode'] as num?)?.toInt() ?? 0;
        return (versionName: name, versionCode: code);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('NativeInstallerService: getAppVersion error: $e');
      return null;
    }
  }
}
