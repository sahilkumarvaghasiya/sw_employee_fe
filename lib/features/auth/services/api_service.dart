import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/http_client_manager.dart';
import 'auth_service.dart';
import 'session_notifier.dart';

class ApiService {
  ApiService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  http.Client get _client => HttpClientManager.client;

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
    await _handleSessionExpiredIfNeeded(firstResponse);
    return firstResponse;
  }

  Future<bool> _handleSessionExpiredIfNeeded(
    http.Response response,
  ) async {
    final message = _extractAuthFailureMessage(response);
    if (message == null) {
      return false;
    }

    await SessionNotifier.notifySessionExpired(message);
    return true;
  }

  String? _extractAuthFailureMessage(http.Response response) {
    if (response.statusCode == 401) {
      return _extractDetail(response) ??
          'Session expired. Please login again.';
    }

    final detail = _extractDetail(response);
    if (detail == null) return null;
    final normalized = detail.toLowerCase();
    if (normalized.contains('session expired') ||
        normalized.contains('authentication_failed') ||
        normalized.contains('token invalid')) {
      return detail;
    }
    return null;
  }

  String? _extractDetail(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code']?.toString().trim();
        final detail = decoded['detail'] ?? decoded['error'] ?? decoded['message'];
        if (code == 'SESSION_REPLACED') {
          return decoded['message']?.toString().trim().isNotEmpty == true
              ? decoded['message'].toString().trim()
              : 'You were logged out because you signed in from another device.';
        }
        if (code == 'TOKEN_INVALID' ||
            code == 'token_not_valid' ||
            code == 'authentication_failed') {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
        if (detail is Map) {
          final nestedCode = detail['code']?.toString().trim();
          final nestedMessage = detail['message']?.toString().trim();
          if (nestedCode == 'SESSION_REPLACED') {
            return nestedMessage?.isNotEmpty == true
                ? nestedMessage!
                : 'You were logged out because you signed in from another device.';
          }
          if (nestedCode == 'TOKEN_INVALID' ||
              nestedCode == 'token_not_valid' ||
              nestedCode == 'authentication_failed') {
            if (nestedMessage != null && nestedMessage.isNotEmpty) {
              return nestedMessage;
            }
          }
          if (nestedMessage != null && nestedMessage.isNotEmpty) {
            return nestedMessage;
          }
        }
        if (detail == null) return null;
        final text = detail.toString().trim();
        if (text.isEmpty) return null;
        if (text == 'Session expired. Logged in from another device.') {
          return 'You were logged out because you signed in from another device.';
        }
        if (text == 'Incorrect authentication credentials.') {
          return 'Access to your account is currently restricted. Please contact the administrator.';
        }
        return text;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<http.Response> get(String url) async {
    return _sendWithAuth((headers) {
      return _client.get(Uri.parse(url), headers: headers);
    });
  }

  Future<http.Response> delete(String url) async {
    return _sendWithAuth((headers) {
      return _client.delete(Uri.parse(url), headers: headers);
    });
  }

  Future<http.Response> put(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    return _sendWithAuth((headers) {
      return _client.put(
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
      return _client.patch(
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
      return _client.post(
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
      return _client.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
    });
  }

  Future<http.Response> getWithoutAuth(String url) async {
    return _client.get(
      Uri.parse(url),
      headers: const {'Content-Type': 'application/json'},
    );
  }
}
