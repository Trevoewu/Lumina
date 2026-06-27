import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyStore {
  static const String _fallbackPrefix = 'api_key_fallback.';

  final FlutterSecureStorage _secureStorage;

  ApiKeyStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String?> read(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null && value.isNotEmpty) return value;
    } on PlatformException catch (error) {
      if (!_isMissingEntitlementError(error)) rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fallbackKey(key));
  }

  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackKey(key));
    } on PlatformException catch (error) {
      if (!_isMissingEntitlementError(error)) rethrow;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackKey(key), value);
    }
  }

  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (error) {
      if (!_isMissingEntitlementError(error)) rethrow;
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackKey(key));
    }
  }

  bool _isMissingEntitlementError(PlatformException error) =>
      error.code == 'Unexpected security result code' &&
      (error.message?.contains('-34018') == true ||
          error.details?.toString().contains('-34018') == true);

  String _fallbackKey(String key) => '$_fallbackPrefix$key';
}
