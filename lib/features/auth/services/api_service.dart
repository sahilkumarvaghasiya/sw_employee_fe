import 'dart:convert';

import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  final TokenStorage _tokenStorage = TokenStorage();

  Future<http.Response> get(String url) async {
    final token = await _tokenStorage.getAccessToken();
    return http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<http.Response> post(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    final token = await _tokenStorage.getAccessToken();
    return http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
