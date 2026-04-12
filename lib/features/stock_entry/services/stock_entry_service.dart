import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/stock_entry_detail.dart';

class GeneratedBarcode {
  const GeneratedBarcode({required this.barcode, required this.barcodeUrl});

  final String barcode;
  final String barcodeUrl;
}

class StockEntryService {
  StockEntryService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  // TODO: Update these paths to match your backend URLs.
  static const String generateBarcodePath = '/stock-entry/generate-barcode/';
  static const String createStockEntryPath = '/stock-entry/create/';
  static const String stockEntryDetailPath = '/stock-entry/detail/';

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

  Future<GeneratedBarcode> generateBarcode() async {
    final response = await _apiService.post(
      _url(generateBarcodePath).toString(),
      body: const {},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to generate barcode (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid generate barcode response');
    }

    final barcode = decoded['barcode']?.toString().trim();
    final barcodeUrl = decoded['barcode_url']?.toString().trim();

    if (barcode == null || barcode.isEmpty) {
      throw const FormatException('Barcode missing in response');
    }
    if (barcodeUrl == null || barcodeUrl.isEmpty) {
      throw const FormatException('barcode_url missing in response');
    }

    return GeneratedBarcode(barcode: barcode, barcodeUrl: barcodeUrl);
  }

  Future<String?> createStockEntry({
    required Map<String, dynamic> payload,
  }) async {
    final response = await _apiService.post(
      _url(createStockEntryPath).toString(),
      body: payload,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          Object? invoice =
              decoded['invoice_number'] ??
              decoded['invoiceNo'] ??
              decoded['invoice'];

          final data = decoded['data'];
          if ((invoice == null || invoice.toString().trim().isEmpty) &&
              data is Map<String, dynamic>) {
            invoice =
                data['invoice_number'] ?? data['invoiceNo'] ?? data['invoice'];
          }

          final value = invoice?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      } catch (_) {
        // ignore non-json/empty responses
      }
      return null;
    }

    String message = 'Failed to save stock entry (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value =
            decoded['error'] ?? decoded['detail'] ?? decoded['message'];
        if (value != null) {
          message = value.toString();
        }
      }
    } catch (_) {
      // ignore
    }

    throw http.ClientException(message);
  }

  Future<StockEntryDetail> fetchStockEntryDetail({
    required String invoiceNumber,
  }) async {
    final response = await _apiService.get(
      _url(
        stockEntryDetailPath,
        queryParameters: {'invoice_number': invoiceNumber},
      ).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load stock entry details (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      map = decoded;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        map = data;
      }
    }

    if (map == null) {
      throw const FormatException('Invalid stock entry details response');
    }

    return StockEntryDetail.fromJson(map);
  }
}
