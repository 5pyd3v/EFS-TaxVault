import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the platform keystore/keychain via
/// [FlutterSecureStorage] instead of supabase_flutter's default
/// SharedPreferences-backed storage — session tokens are credentials and
/// belong in secure storage, not plain-text prefs.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    FlutterSecureStorage? secureStorage,
    this.persistSessionKey = 'efs_taxvault_session',
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  final String persistSessionKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return (await _secureStorage.read(key: persistSessionKey)) != null;
  }

  @override
  Future<String?> accessToken() {
    return _secureStorage.read(key: persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() {
    return _secureStorage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _secureStorage.write(
      key: persistSessionKey,
      value: persistSessionString,
    );
  }
}
