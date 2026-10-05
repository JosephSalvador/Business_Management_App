import 'package:flutter/services.dart';

/// Reads the user's system font scale from the native platform.
///
/// Font SIZE scaling is handled automatically by Flutter's MediaQuery.
/// This service is a backup for cases where you need the raw scale value.
class SystemFontService {
  SystemFontService._();

  static const _channel = MethodChannel('com.jolinx.app/system_font');

  /// Returns the system font scale factor (1.0 = default).
  ///
  /// On Android this reflects Settings → Display → Font size.
  static Future<double> getFontScale() async {
    try {
      final result = await _channel.invokeMethod<double>('getFontScale');
      return result ?? 1.0;
    } on PlatformException {
      return 1.0;
    }
  }
}
