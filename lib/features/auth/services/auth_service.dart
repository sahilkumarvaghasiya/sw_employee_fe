import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class AuthService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'access': data['access'], 'refresh': data['refresh']};
    } else {
      throw Exception('Login failed');
    }
  }

  Future<void> changePassword({
    required String accessToken,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'newPassword': newPassword}),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw Exception('Change password failed');
  }
}
