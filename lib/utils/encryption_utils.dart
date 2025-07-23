import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionUtils {
  static const _keyStorageKey = 'encryption_key';
  static final _secureStorage = const FlutterSecureStorage();
  static Key? _cachedKey;

  /// Get or generate a 32-byte AES key, stored securely on device
  static Future<Key> getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    String? keyString = await _secureStorage.read(key: _keyStorageKey);
    if (keyString == null) {
      final key = Key.fromSecureRandom(32);
      keyString = base64UrlEncode(key.bytes);
      await _secureStorage.write(key: _keyStorageKey, value: keyString);
      _cachedKey = key;
      return key;
    }
    final key = Key(base64Url.decode(keyString));
    _cachedKey = key;
    return key;
  }

  /// Encrypt a string using AES
  static Future<String> encryptField(String value) async {
    final key = await getKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(value, iv: iv);
    // Store IV with ciphertext (IV:ciphertext)
    return base64UrlEncode(iv.bytes) + ':' + encrypted.base64;
  }

  /// Decrypt a string using AES
  static Future<String> decryptField(String encryptedValue) async {
    final key = await getKey();
    final parts = encryptedValue.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted format');
    final iv = IV(base64Url.decode(parts[0]));
    final encrypter = Encrypter(AES(key));
    final decrypted = encrypter.decrypt64(parts[1], iv: iv);
    return decrypted;
  }
} 