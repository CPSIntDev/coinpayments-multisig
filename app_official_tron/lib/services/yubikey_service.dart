import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Service for YubiKey authentication
/// 
/// YubiKey OTP format: First 12 characters are the public identity (modhex),
/// followed by the encrypted OTP. The public identity is unique per YubiKey.
class YubiKeyService {
  static const String _publicIdPref = 'yubikey_public_id';
  static const String _enabledPref = 'yubikey_enabled';

  /// Get prefixed key for current instance
  static String _key(String base) => StorageService.key(base);

  /// Minimum valid YubiKey OTP length (12 char ID + 32 char OTP)
  static const int minOtpLength = 44;

  /// Public identity length in YubiKey OTP
  static const int publicIdLength = 12;

  /// Valid modhex characters used by YubiKey
  static const String modhexChars = 'cbdefghijklnrtuv';

  /// Validates if the string looks like a YubiKey OTP
  static bool isValidOtp(String otp) {
    if (otp.length < minOtpLength) return false;
    // YubiKey uses modhex encoding (only certain characters)
    return otp.toLowerCase().split('').every((c) => modhexChars.contains(c));
  }

  /// Extracts the public identity from a YubiKey OTP
  static String? extractPublicId(String otp) {
    if (!isValidOtp(otp)) return null;
    return otp.substring(0, publicIdLength).toLowerCase();
  }

  /// Saves the YubiKey public identity
  static Future<void> savePublicId(String otp) async {
    final publicId = extractPublicId(otp);
    if (publicId == null) {
      throw Exception('Invalid YubiKey OTP');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_publicIdPref), publicId);
    await prefs.setBool(_key(_enabledPref), true);
    // ignore: avoid_print
    print('[YubiKey] Saved public ID: $publicId (instance: ${StorageService.instanceId})');
  }

  /// Gets the stored public identity
  static Future<String?> getPublicId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(_publicIdPref));
  }

  /// Checks if YubiKey is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_enabledPref)) ?? false;
  }

  /// Verifies that the OTP matches the stored public identity
  static Future<bool> verifyOtp(String otp) async {
    final storedId = await getPublicId();
    if (storedId == null) return false;

    final providedId = extractPublicId(otp);
    if (providedId == null) return false;

    final matches = storedId == providedId;
    // ignore: avoid_print
    print('[YubiKey] Verify: stored=$storedId, provided=$providedId, matches=$matches');
    return matches;
  }

  /// Removes YubiKey configuration
  static Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(_publicIdPref));
    await prefs.remove(_key(_enabledPref));
    // ignore: avoid_print
    print('[YubiKey] Removed (instance: ${StorageService.instanceId})');
  }
}
