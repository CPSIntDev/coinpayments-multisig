import 'package:shared_preferences/shared_preferences.dart';

/// Service for isolated storage between app instances
/// Allows running multiple instances with independent data
class StorageService {
  static String _instanceId = '';
  
  /// Initialize with optional instance ID (from environment/args)
  static void setInstanceId(String id) {
    _instanceId = id;
    // ignore: avoid_print
    print('[StorageService] Instance ID set to: ${id.isEmpty ? "default" : id}');
  }
  
  /// Get the current instance ID
  static String get instanceId => _instanceId;
  
  /// Get prefixed key for isolated storage
  static String key(String baseKey) {
    if (_instanceId.isEmpty) return baseKey;
    return '${_instanceId}_$baseKey';
  }
  
  /// Get SharedPreferences with automatic key prefixing
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageService.key(key));
  }
  
  static Future<bool> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(StorageService.key(key), value);
  }
  
  static Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageService.key(key));
  }
  
  static Future<bool> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(StorageService.key(key), value);
  }
  
  static Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageService.key(key));
  }
  
  static Future<bool> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(StorageService.key(key), value);
  }
  
  static Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(StorageService.key(key));
  }
  
  /// Clear all data for current instance
  static Future<void> clearInstance() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final prefix = _instanceId.isEmpty ? '' : '${_instanceId}_';
    
    for (final key in keys) {
      if (prefix.isEmpty || key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }
}
