import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/stock_alert.dart';

/// Result of `GET /sales/notifications/`.
class SalesNotificationsResult {
  const SalesNotificationsResult({
    required this.totalUnseen,
    required this.notifications,
  });

  final int totalUnseen;
  final List<StockAlert> notifications;
}

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

  Future<SalesNotificationsResult> fetchNotificationsList() async {
    final response = await _apiService.get(
      _url('/sales/notifications/').toString(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw http.ClientException('Invalid notifications response');
      }

      final totalRaw =
          decoded['total_unseen'] ?? decoded['totalUnseen'] ?? 0;
      final totalUnseen = int.tryParse(totalRaw.toString()) ?? 0;

      final listRaw = decoded['notifications'];
      final List<dynamic> list = listRaw is List ? listRaw : const [];

      final notifications = list
          .whereType<Map<String, dynamic>>()
          .map(StockAlert.fromJson)
          .toList(growable: false);

      return SalesNotificationsResult(
        totalUnseen: totalUnseen,
        notifications: notifications,
      );
    }

    throw http.ClientException('Failed to fetch notifications');
  }

  Future<void> markAllSeen() async {
    final response = await _apiService.post(
      _url('/sales/notifications/mark-seen/').toString(),
      body: const {},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    throw http.ClientException('Failed to mark alerts seen');
  }
}
