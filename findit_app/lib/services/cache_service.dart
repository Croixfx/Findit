import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _prefix = 'api_cache_';

  static Future<void> set(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(data));
    } catch (_) {}
  }

  static Future<dynamic> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
