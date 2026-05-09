import 'dart:convert';

import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'session_notifier.dart';

class ApiService {
  ApiService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Map<String, String> _buildHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _sendWithAuth(
    Future<http.Response> Function(Map<String, String> headers) sender,
  ) async {
    final accessToken = await _authService.getValidAccessToken();
    if (accessToken == null) {
      return http.Response('{"error":"Unauthenticated"}', 401);
    }

    final firstResponse = await sender(_buildHeaders(accessToken));
    if (await _handleSessionExpiredIfNeeded(firstResponse)) {
      return firstResponse;
    }
    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    final refreshedAccessToken = await _authService.refreshAccessToken();
    if (refreshedAccessToken == null) {
      return firstResponse;
    }

    final refreshedResponse =
        await sender(_buildHeaders(refreshedAccessToken));
    await _handleSessionExpiredIfNeeded(refreshedResponse);
    return refreshedResponse;
  }

  Future<bool> _handleSessionExpiredIfNeeded(
    http.Response response,
  ) async {
    final message = _extractSessionExpiredMessage(response);
    if (message == null) {
      return false;
    }

    await SessionNotifier.notifySessionExpired(message);
    return true;
  }

  String? _extractSessionExpiredMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString();
        if (detail == null) return null;
        if (detail ==
            'Session expired. Logged in from another device.') {
          return 'You were logged out because you signed in from another device.';
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<http.Response> get(String url) async {
    return _sendWithAuth((headers) {
      return http.get(Uri.parse(url), headers: headers);
    });
  }

  Future<http.Response> delete(String url) async {
    return _sendWithAuth((headers) {
      return http.delete(Uri.parse(url), headers: headers);
    });
  }

  Future<http.Response> put(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    return _sendWithAuth((headers) {
      return http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  Future<http.Response> patch(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    return _sendWithAuth((headers) {
      return http.patch(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  Future<http.Response> post(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    return _sendWithAuth((headers) {
      return http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  Future<http.Response> postRaw(
    String url, {
    required String body,
  }) async {
    return _sendWithAuth((headers) {
      return http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
    });
  }

  Future<http.Response> getWithoutAuth(String url) async {
    return http.get(
      Uri.parse(url),
      headers: const {'Content-Type': 'application/json'},
    );
  }
}
