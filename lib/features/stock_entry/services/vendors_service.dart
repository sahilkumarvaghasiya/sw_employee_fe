import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/vendor.dart';

class VendorsPage {
  const VendorsPage({
    required this.vendors,
    required this.hasNext,
    required this.count,
  });

  final List<Vendor> vendors;
  final bool hasNext;
  final int count;
}

class VendorsService {
  VendorsService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String vendorsListPath = '/vendors/list/';

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

  /// One page from BE (`VendorListPagination`, default page_size=20).
  Future<VendorsPage> fetchVendorsPage({
    String? search,
    int page = 1,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
    };
    final query = (search ?? '').trim();
    if (query.isNotEmpty) qp['search'] = query;

    final url = _url(vendorsListPath, queryParameters: qp).toString();
    http.Response response;
    try {
      response = await _apiService.get(url);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VendorsService.fetchVendorsPage error: $e');
        debugPrint('VendorsService.fetchVendorsPage url: $url');
      }
      throw http.ClientException(
        'Cannot connect to backend. Check API URL (${ApiConfig.baseUrl}). '
        'If you are running on a physical phone, set ApiConfig.usePhysicalDeviceBaseUrl=true and use your PC IP/Ngrok.',
      );
    }

    if (kDebugMode) {
      debugPrint(
        'VendorsService.fetchVendorsPage ${response.statusCode} (${response.bodyBytes.length} bytes)',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final value =
              parsed['error'] ?? parsed['detail'] ?? parsed['message'];
          if (value != null) detail = value.toString();
        }
      } catch (_) {
        // ignore
      }

      if (response.statusCode == 401) {
        throw http.ClientException(
          'Unauthorized (401). Please login again so the app has a valid token.',
        );
      }

      throw http.ClientException(
        'Failed to load vendors (${response.statusCode})'
        '${detail == null || detail.trim().isEmpty ? '' : ': $detail'}',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic>? rows;
    var hasNext = false;
    var count = 0;

    if (decoded is List) {
      rows = decoded;
      count = decoded.length;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['data'] ?? decoded['results'] ?? decoded['items'];
      if (data is List) rows = data;
      final next = decoded['next'];
      hasNext = next != null && next.toString().trim().isNotEmpty;
      final countRaw = decoded['count'];
      if (countRaw is int) {
        count = countRaw;
      } else {
        count = int.tryParse(countRaw?.toString() ?? '') ?? (rows?.length ?? 0);
      }
    }

    if (rows == null) {
      throw const FormatException('Invalid vendor list response');
    }

    final out = <Vendor>[];
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        out.add(Vendor.fromJson(row));
      } else if (row is Map) {
        out.add(Vendor.fromJson(row.cast<String, dynamic>()));
      }
    }

    return VendorsPage(vendors: out, hasNext: hasNext, count: count);
  }
}
