import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Secure storage for tokens
  Future<void> saveToken(String token) =>
      _secureStorage.write(key: 'access_token', value: token);

  Future<String?> getToken() => _secureStorage.read(key: 'access_token');

  Future<void> saveRefreshToken(String token) =>
      _secureStorage.write(key: 'refresh_token', value: token);

  Future<String?> getRefreshToken() =>
      _secureStorage.read(key: 'refresh_token');

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  // General prefs
  bool get isLoggedIn => _prefs.getBool('is_logged_in') ?? false;
  Future<void> setLoggedIn(bool value) =>
      _prefs.setBool('is_logged_in', value);
}
