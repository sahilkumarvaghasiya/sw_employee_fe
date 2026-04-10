import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/stock_alert.dart';

class StockAlertsService {
  StockAlertsService({ApiService? apiService})
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

  Future<int> fetchUnseenCount() async {
    final response = await _apiService.get(
      _url('/stock-alerts/unseen-count').toString(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);

      Map<String, dynamic>? map;
      if (decoded is Map<String, dynamic>) {
        map = decoded;
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          map = data;
        }
      }

      if (map == null) return 0;

      final raw =
          map['count'] ??
          map['unseenCount'] ??
          map['unreadCount'] ??
          map['unseen'] ??
          map['unread'] ??
          map['unseen_count'] ??
          map['unread_count'];

      final parsed = int.tryParse((raw ?? 0).toString());
      return parsed ?? 0;
    }

    throw http.ClientException('Failed to fetch unseen count');
  }

  Future<List<StockAlert>> fetchAlerts() async {
    final response = await _apiService.get(_url('/stock-alerts').toString());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);

      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
      } else if (decoded is Map<String, dynamic> && decoded['alerts'] is List) {
        list = decoded['alerts'] as List<dynamic>;
      } else {
        list = const [];
      }

      return list
          .whereType<Map<String, dynamic>>()
          .map(StockAlert.fromJson)
          .toList(growable: false);
    }

    throw http.ClientException('Failed to fetch alerts');
  }

  Future<void> markAllSeen() async {
    final response = await _apiService.post(
      _url('/stock-alerts/mark-all-seen').toString(),
      body: const {},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    throw http.ClientException('Failed to mark alerts seen');
  }
}
