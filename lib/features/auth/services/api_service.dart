import 'dart:convert';

import 'package:http/http.dart' as http;
import 'auth_service.dart';

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
    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    final refreshedAccessToken = await _authService.refreshAccessToken();
    if (refreshedAccessToken == null) {
      return firstResponse;
    }

    return sender(_buildHeaders(refreshedAccessToken));
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
