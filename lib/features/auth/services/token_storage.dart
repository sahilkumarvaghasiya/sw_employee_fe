import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenVersionKey = 'token_version';
  static const _userNameKey = 'user_name';
  static const _shopNameKey = 'shop_name';
  final _secureStorage = FlutterSecureStorage();
  static final Future<SharedPreferences> _webPrefs =
      SharedPreferences.getInstance();

  Future<void> _writeValue(String key, String? value) async {
    if (kIsWeb) {
      final prefs = await _webPrefs;
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> _readValue(String key) async {
    if (kIsWeb) {
      final prefs = await _webPrefs;
      return prefs.getString(key);
    }
    return await _secureStorage.read(key: key);
  }

  Future<void> _deleteValue(String key) async {
    if (kIsWeb) {
      final prefs = await _webPrefs;
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

  Future<void> saveTokens(String access, String refresh,
      {String? tokenVersion}) async {
    await _writeValue(_accessTokenKey, access);
    await _writeValue(_refreshTokenKey, refresh);
    if (tokenVersion != null) {
      await _writeValue(_tokenVersionKey, tokenVersion);
    }
  }

  Future<String?> getAccessToken() async {
    return await _readValue(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _readValue(_refreshTokenKey);
  }

  Future<String?> getTokenVersion() async {
    return await _readValue(_tokenVersionKey);
  }

  Future<void> saveUserContext({
    required String userName,
    required String shopName,
  }) async {
    await _writeValue(_userNameKey, userName);
    await _writeValue(_shopNameKey, shopName);
  }

  Future<String?> getUserName() async {
    return await _readValue(_userNameKey);
  }

  Future<String?> getShopName() async {
    return await _readValue(_shopNameKey);
  }

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.trim().isNotEmpty;
  }

  Future<void> deleteTokens() async {
    await _deleteValue(_accessTokenKey);
    await _deleteValue(_refreshTokenKey);
    await _deleteValue(_tokenVersionKey);
    await _deleteValue(_userNameKey);
    await _deleteValue(_shopNameKey);
  }
}
