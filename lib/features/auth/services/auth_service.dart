import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import 'token_storage.dart';

class AuthService {
  AuthService({http.Client? client, TokenStorage? tokenStorage})
    : _client = client ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  static Future<String?>? _refreshInFlight;

  String get _baseUrl => _normalizeBase(ApiConfig.baseUrl);
  String get _accountBaseUrl => '$_baseUrl/account';

  static String _normalizeBase(String base) {
    final trimmed = base.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Uri _accountUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_accountBaseUrl$normalizedPath');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client
          .post(
            _accountUri('/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access']?.toString();
        final refresh = data['refresh']?.toString();

        if (access == null || refresh == null) {
          throw Exception('Invalid login response from server');
        }

        return {...data, 'access': access, 'refresh': refresh};
      }

      throw Exception(_errorMessageFromResponse(response));
    } on TimeoutException {
      throw Exception('Request timed out. Backend is slow or unreachable.');
    } on SocketException {
      throw Exception(
        'Cannot connect to backend. Check API URL and ensure server is reachable from this device.',
      );
    } on FormatException {
      throw Exception('Invalid response format from backend.');
    }
  }

  Future<bool> restoreSession() async {
    final refreshedAccess = await getValidAccessToken();
    return refreshedAccess != null;
  }

  Future<String?> getValidAccessToken() async {
    final accessToken = await _tokenStorage.getAccessToken();

    if (accessToken != null && !_isJwtExpired(accessToken)) {
      return accessToken;
    }

    return await refreshAccessToken();
  }

  Future<String?> refreshAccessToken() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    final request = _refreshAccessTokenInternal();
    _refreshInFlight = request;

    request.whenComplete(() {
      if (identical(_refreshInFlight, request)) {
        _refreshInFlight = null;
      }
    });

    return request;
  }

  Future<String?> _refreshAccessTokenInternal() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await _tokenStorage.deleteTokens();
      return null;
    }

    if (_isJwtExpired(refreshToken, grace: Duration.zero)) {
      await _tokenStorage.deleteTokens();
      return null;
    }

    final response = await _client.post(
      _accountUri('/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = data['access']?.toString();
      if (newAccess == null || newAccess.trim().isEmpty) {
        await _tokenStorage.deleteTokens();
        return null;
      }

      final rotatedRefresh = data['refresh']?.toString() ?? refreshToken;
      await _tokenStorage.saveTokens(newAccess, rotatedRefresh);
      return newAccess;
    }

    await _tokenStorage.deleteTokens();
    return null;
  }

  Future<void> changePassword({required String newPassword}) async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client.post(
      _accountUri('/change-password/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'newPassword': newPassword}),
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      final refreshedAccess = await refreshAccessToken();
      if (refreshedAccess == null) {
        throw Exception('Session expired. Please login again.');
      }

      final retry = await _client.post(
        _accountUri('/change-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshedAccess',
        },
        body: jsonEncode({'newPassword': newPassword}),
      );

      if (retry.statusCode == 200) {
        return;
      }
    }

    throw Exception('Change password failed');
  }

  bool _isJwtExpired(
    String token, {
    Duration grace = const Duration(seconds: 30),
  }) {
    final exp = _jwtExp(token);
    if (exp == null) return true;
    final now = DateTime.now().add(grace).millisecondsSinceEpoch ~/ 1000;
    return exp <= now;
  }

  int? _jwtExp(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadMap =
          jsonDecode(utf8.decode(base64Url.decode(normalizedPayload)))
              as Map<String, dynamic>;
      final expValue = payloadMap['exp'];
      if (expValue is int) return expValue;
      if (expValue is String) return int.tryParse(expValue);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _errorMessageFromResponse(http.Response response) {
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        final value = parsed['error'] ?? parsed['detail'] ?? parsed['message'];
        if (value != null) {
          return value.toString();
        }
      }
    } catch (_) {
      // ignore parse errors and fallback to status-based message.
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      return 'Invalid email or password';
    }

    return 'Login failed (${response.statusCode})';
  }
}
