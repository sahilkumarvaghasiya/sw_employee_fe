import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenVersionKey = 'token_version';
  static const _userNameKey = 'user_name';
  static const _shopNameKey = 'shop_name';
  final _storage = FlutterSecureStorage();

  Future<void> saveTokens(String access, String refresh,
      {String? tokenVersion}) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
    if (tokenVersion != null) {
      await _storage.write(key: _tokenVersionKey, value: tokenVersion);
    }
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<String?> getTokenVersion() async {
    return await _storage.read(key: _tokenVersionKey);
  }

  Future<void> saveUserContext({
    required String userName,
    required String shopName,
  }) async {
    await _storage.write(key: _userNameKey, value: userName);
    await _storage.write(key: _shopNameKey, value: shopName);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  Future<String?> getShopName() async {
    return await _storage.read(key: _shopNameKey);
  }

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.trim().isNotEmpty;
  }

  Future<void> deleteTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenVersionKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _shopNameKey);
  }
}
