import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _tokenKey = 'access_token';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('StorageService.init() must be called before use.');
    }
    return prefs;
  }

  Future<void> saveToken(String token) async {
    await _store.setString(_tokenKey, token);
  }

  Future<String?> getToken() async => _store.getString(_tokenKey);

  Future<void> clearTokens() async {
    await _store.remove(_tokenKey);
  }
}
