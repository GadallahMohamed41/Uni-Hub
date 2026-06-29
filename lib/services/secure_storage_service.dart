import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  // Configure maximum native security for both platforms
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Write a key-value pair to secure encrypted storage.
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure encrypted storage. Returns null if not found.
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a specific key from secure encrypted storage.
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Clear all secure storage entries.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
