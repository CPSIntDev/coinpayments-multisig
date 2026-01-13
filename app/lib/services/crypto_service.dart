import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Service for encrypting/decrypting private keys using AES-256-GCM
/// Uses the cryptography package with platform-optimized implementations
class CryptoService {
  static const String _encryptedKeyPref = 'encrypted_private_key';
  static const String _saltPref = 'encryption_salt';
  static const String _noncePref = 'encryption_nonce';
  static const String _hasWalletPref = 'has_wallet';

  /// AES-GCM cipher with 256-bit key (authenticated encryption)
  static final AesGcm _cipher = FlutterAesGcm.with256bits();

  /// PBKDF2 for key derivation
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256, // 256-bit key for AES-256
  );

  /// Get prefixed key for current instance
  static String _key(String base) => StorageService.key(base);

  /// Derives a 256-bit key from password using PBKDF2
  static Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return secretKey;
  }

  /// Encrypts the private key with the given password
  static Future<void> saveEncryptedKey(String privateKey, String password) async {
    // ignore: avoid_print
    print('[CryptoService] saveEncryptedKey called (instance: ${StorageService.instanceId})');
    
    try {
      final prefs = await SharedPreferences.getInstance();

      // Normalize key - remove 0x prefix if present
      String normalizedKey = privateKey;
      if (privateKey.startsWith('0x')) {
        normalizedKey = privateKey.substring(2);
      }

      // ignore: avoid_print
      print('[CryptoService] Saving key of length: ${normalizedKey.length}, password length: ${password.length}');

      // Generate random salt and nonce
      final salt = _cipher.newNonce(); // 12 bytes for GCM nonce, reused as salt
      final nonce = _cipher.newNonce(); // 12 bytes for AES-GCM

      // Derive key from password
      final key = await _deriveKey(password, salt);

      // Encrypt the private key with AES-GCM (authenticated encryption)
      final secretBox = await _cipher.encrypt(
        utf8.encode(normalizedKey),
        secretKey: key,
        nonce: nonce,
      );

      // Combine ciphertext and MAC for storage
      final encryptedData = Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      // Save to preferences with instance-specific keys
      await prefs.setString(_key(_encryptedKeyPref), base64.encode(encryptedData));
      await prefs.setString(_key(_saltPref), base64.encode(salt));
      await prefs.setString(_key(_noncePref), base64.encode(nonce));
      await prefs.setBool(_key(_hasWalletPref), true);

      // Verify save worked
      final verify = prefs.getString(_key(_encryptedKeyPref));
      // ignore: avoid_print
      print('[CryptoService] Key encrypted and saved. Verify: ${verify != null ? 'OK' : 'FAILED'}');
    } catch (e) {
      // ignore: avoid_print
      print('[CryptoService] ERROR in saveEncryptedKey: $e');
      rethrow;
    }
  }

  /// Decrypts the private key with the given password
  /// Returns null if decryption fails (wrong password)
  static Future<String?> decryptKey(String password) async {
    final prefs = await SharedPreferences.getInstance();

    final encryptedBase64 = prefs.getString(_key(_encryptedKeyPref));
    final saltBase64 = prefs.getString(_key(_saltPref));
    final nonceBase64 = prefs.getString(_key(_noncePref));
    final hasWalletFlag = prefs.getBool(_key(_hasWalletPref));

    // ignore: avoid_print
    print('[CryptoService] Attempting to decrypt key (instance: ${StorageService.instanceId})...');
    // ignore: avoid_print
    print('[CryptoService] Password length: ${password.length}');
    // ignore: avoid_print
    print('[CryptoService] Has encrypted data: ${encryptedBase64 != null}, length: ${encryptedBase64?.length}');
    // ignore: avoid_print
    print('[CryptoService] Has salt: ${saltBase64 != null}, Has nonce: ${nonceBase64 != null}, Flag: $hasWalletFlag');
    // ignore: avoid_print
    print('[CryptoService] Keys being used: ${_key(_encryptedKeyPref)}, ${_key(_saltPref)}, ${_key(_noncePref)}');

    if (encryptedBase64 == null || saltBase64 == null || nonceBase64 == null) {
      // ignore: avoid_print
      print('[CryptoService] Missing encryption data - wallet may not be saved properly');
      throw Exception('No wallet data found. Please set up your wallet again.');
    }

    try {
      // Restore salt and nonce
      final salt = base64.decode(saltBase64);
      final nonce = base64.decode(nonceBase64);
      final encryptedData = base64.decode(encryptedBase64);

      // Split ciphertext and MAC (MAC is last 16 bytes for AES-GCM)
      final macLength = 16;
      final cipherText = encryptedData.sublist(0, encryptedData.length - macLength);
      final mac = Mac(encryptedData.sublist(encryptedData.length - macLength));

      // Derive key from password
      final key = await _deriveKey(password, salt);

      // Create SecretBox from stored data
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

      // Decrypt with authentication check
      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: key,
      );
      
      final decrypted = utf8.decode(decryptedBytes);

      // ignore: avoid_print
      print('[CryptoService] Decrypted value length: ${decrypted.length}');

      // Validate it looks like a private key (64 hex characters)
      if (decrypted.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(decrypted)) {
        // ignore: avoid_print
        print('[CryptoService] Decryption successful - valid hex key');
        return decrypted;
      }

      // ignore: avoid_print
      print('[CryptoService] Decrypted value is not valid hex key (length: ${decrypted.length}, first 10 chars: ${decrypted.substring(0, decrypted.length > 10 ? 10 : decrypted.length)})');
      return null;
    } on SecretBoxAuthenticationError {
      // Authentication failed - wrong password or corrupted data
      // ignore: avoid_print
      print('[CryptoService] Authentication failed - wrong password');
      return null;
    } catch (e) {
      // Other decryption errors
      // ignore: avoid_print
      print('[CryptoService] Decryption error: $e');
      // Check for common error patterns indicating wrong password
      if (e.toString().contains('authentication') || 
          e.toString().contains('mac') ||
          e.toString().contains('tag')) {
        return null; // Wrong password - return null silently
      }
      rethrow; // Other errors should be shown
    }
  }

  /// Checks if a wallet is saved
  static Future<bool> hasWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final has = prefs.getBool(_key(_hasWalletPref)) ?? false;
    final hasKey = prefs.getString(_key(_encryptedKeyPref)) != null;
    // ignore: avoid_print
    print('[CryptoService] hasWallet check (instance: ${StorageService.instanceId}): flag=$has, hasEncryptedKey=$hasKey');
    return has && hasKey;
  }

  /// Deletes the saved wallet
  static Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(_encryptedKeyPref));
    await prefs.remove(_key(_saltPref));
    await prefs.remove(_key(_noncePref));
    await prefs.remove(_key(_hasWalletPref));
    // ignore: avoid_print
    print('[CryptoService] Wallet deleted (instance: ${StorageService.instanceId})');
  }

  /// Changes the password for the encrypted key
  static Future<bool> changePassword(String oldPassword, String newPassword) async {
    final privateKey = await decryptKey(oldPassword);
    if (privateKey == null) {
      return false;
    }
    await saveEncryptedKey(privateKey, newPassword);
    return true;
  }
}
