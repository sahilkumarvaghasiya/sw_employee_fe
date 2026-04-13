import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/vendor.dart';

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

  Future<List<Vendor>> fetchVendors() async {
    final url = _url(vendorsListPath).toString();
    http.Response response;
    try {
      response = await _apiService.get(url);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VendorsService.fetchVendors error: $e');
        debugPrint('VendorsService.fetchVendors url: $url');
      }
      throw http.ClientException(
        'Cannot connect to backend. Check API URL (${ApiConfig.baseUrl}). '
        'If you are running on a physical phone, set ApiConfig.usePhysicalDeviceBaseUrl=true and use your PC IP/Ngrok.',
      );
    }

    if (kDebugMode) {
      debugPrint(
        'VendorsService.fetchVendors ${response.statusCode} (${response.bodyBytes.length} bytes)',
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

    List<dynamic>? list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['data'] ?? decoded['results'] ?? decoded['items'];
      if (data is List) list = data;
    }

    if (list == null) {
      throw const FormatException('Invalid vendor list response');
    }

    final out = <Vendor>[];
    for (final row in list) {
      if (row is Map<String, dynamic>) {
        out.add(Vendor.fromJson(row));
      }
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }
}
