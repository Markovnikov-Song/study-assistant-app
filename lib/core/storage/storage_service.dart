import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final _secureStorage = const FlutterSecureStorage();

  Future<void> init() async {}

  Future<void> saveToken(String token) =>
      _secureStorage.write(key: 'access_token', value: token);

  Future<String?> getToken() => _secureStorage.read(key: 'access_token');

  Future<void> clearTokens() =>
      _secureStorage.delete(key: 'access_token');
}
