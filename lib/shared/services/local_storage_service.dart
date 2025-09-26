import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static SharedPreferences? _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static Future<void> setString(String key, String value) async {
    await _preferences?.setString(key, value);
  }

  static String? getString(String key) {
    return _preferences?.getString(key);
  }

  static Future<void> remove(String key) async {
    await _preferences?.remove(key);
  }

  static Future<void> clear() async {
    await _preferences?.clear();
  }
}