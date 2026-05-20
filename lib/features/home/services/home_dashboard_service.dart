import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/home_dashboard_data.dart';

class HomeDashboardService {
  HomeDashboardService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static Uri _url(String path) {
    final base = ApiConfig.baseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<HomeDashboardData> fetchTodaySummary() async {
    final response = await _apiService.get(
      _url('/sales/today-summary/').toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load today summary (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw http.ClientException('Invalid today summary response');
    }

    return HomeDashboardData.fromJson(decoded);
  }
}
