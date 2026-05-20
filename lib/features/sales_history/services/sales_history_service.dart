import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/sales_bill.dart';

class SalesHistoryService {
  SalesHistoryService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String _historyListPath = '/sales/historylist/';
  static const String _historyDetailsPath = '/sales/saleshistory/details/';

  static Uri _url(String path, {Map<String, String>? queryParameters}) {
    final base = ApiConfig.baseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  static String _ddMMyyyyDash(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  Future<List<SalesBill>> fetchSalesHistoryList({
    String? search,
    DateTime? startDate,
    DateTime? endDate,
    double? maxTotal,
  }) async {
    final qp = <String, String>{};

    final query = (search ?? '').trim();
    if (query.isNotEmpty) qp['search'] = query;

    if (startDate != null) qp['start_date'] = _ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = _ddMMyyyyDash(endDate);
    if (maxTotal != null) qp['max_total'] = maxTotal.toStringAsFixed(2);

    final response = await _apiService.get(
      _url(_historyListPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load sales history (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic>? rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['results'] ?? decoded['data'] ?? decoded['items'];
      if (data is List) rows = data;
    }

    if (rows == null) {
      throw const FormatException('Invalid sales history list response');
    }

    return rows
        .whereType<Map>()
        .map((e) => SalesBill.fromHistoryListJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<SalesBill> fetchSalesHistoryDetails(String billId) async {
    final normalizedId = billId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Sales bill id is required');
    }

    final response = await _apiService.get(
      _url('$_historyDetailsPath$normalizedId/').toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load sales history details (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid sales history details response');
    }

    return SalesBill.fromHistoryDetailsJson(decoded);
  }
}
