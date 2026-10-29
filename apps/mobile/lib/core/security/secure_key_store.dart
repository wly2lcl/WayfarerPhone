import 'package:engine/engine.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 引擎 KeyStore 的实现：密钥只进 Keychain / Keystore，不落明文盘。
/// 固定单一存储键，设置页复用同一个键读写。
class SecureKeyStore implements KeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'wayfarer.model_key';
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() =>
      _storage.read(key: _storageKey, iOptions: _iosOptions);

  @override
  Future<void> write(String key) =>
      _storage.write(key: _storageKey, value: key, iOptions: _iosOptions);

  @override
  Future<void> clear() =>
      _storage.delete(key: _storageKey, iOptions: _iosOptions);
}
