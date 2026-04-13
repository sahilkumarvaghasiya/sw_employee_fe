import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/stock_entry.dart';
import '../models/vendor.dart';
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

  // Backend routes (baseUrl already includes `/api`).
  // From curl:
  // POST /api/vendors/stock/generate-barcode/
  static const String generateBarcodePath = '/vendors/stock/generate-barcode/';

  // From curl:
  // POST /api/vendors/stock/create/                (new vendor)
  // POST /api/vendors/existing/<int:id>/stock/create/ (existing vendor)
  static const String createNewVendorStockEntryPath = '/vendors/stock/create/';
  static String createExistingVendorStockEntryPath(String vendorId) {
    final safeId = Uri.encodeComponent(vendorId);
    return '/vendors/existing/$safeId/stock/create/';
  }

  // From curl:
  // /api/vendors/stock/history/details/?invoice_number=...
  static const String stockEntryDetailPath = '/vendors/stock/history/details/';

  // From curl:
  // /api/vendors/stock/<vendorId>/history/list/
  static String stockEntryHistoryListPath(String vendorId) {
    final safeId = Uri.encodeComponent(vendorId);
    return '/vendors/stock/$safeId/history/list/';
  }

  static String _ddMMyyyyDash(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  static String? _parseBackendStatus(Object? value) {
    final v = value?.toString().trim().toLowerCase();
    if (v == null || v.isEmpty) return null;

    // Backend uses: paid | unpaid | partial
    // Older samples may use: half_paid
    switch (v) {
      case 'paid':
      case 'unpaid':
      case 'partial':
      case 'half_paid':
        return v;
    }
    return null;
  }

  static DateTime _parseBestEffortDate(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return DateTime.now();

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    // dd-MM-yyyy or dd/MM/yyyy
    final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$').firstMatch(raw);
    if (match != null) {
      final dd = int.tryParse(match.group(1)!) ?? 1;
      final mm = int.tryParse(match.group(2)!) ?? 1;
      final yyyy = int.tryParse(match.group(3)!) ?? 1970;
      return DateTime(yyyy, mm, dd);
    }

    return DateTime.now();
  }

  static double _parseDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final raw = value.toString().replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0;
  }

  static StockEntry _historyEntryFromJson(
    Map<String, dynamic> json,
    Vendor vendor,
  ) {
    final invoice =
        (json['invoice_number'] ?? json['invoiceNo'] ?? json['invoice'])
            ?.toString();

    final created = _parseBestEffortDate(
      json['created_date'] ?? json['createdAt'] ?? json['created_at'],
    );

    var total = _parseDouble(
      json['total_amount'] ?? json['totalPayment'] ?? json['total'],
    );
    var paid = _parseDouble(
      json['paid_amount'] ?? json['paidAmount'] ?? json['paid'],
    );
    final pending = _parseDouble(
      json['pending_amount'] ?? json['pendingAmount'] ?? json['due_amount'],
    );

    // Backend sends pending_amount; use it to derive missing totals safely.
    if (total <= 0.0001 && (paid > 0.0001 || pending > 0.0001)) {
      total = paid + pending;
    }
    if (paid <= 0.0001 && total > 0.0001 && pending > 0.0001) {
      paid = total - pending;
      if (paid < 0) paid = 0;
    }

    return StockEntry(
      id: (json['id'] ?? invoice ?? 'se_${created.millisecondsSinceEpoch}')
          .toString(),
      invoiceNumber: invoice?.trim().isEmpty ?? true ? null : invoice?.trim(),
      backendStatus: _parseBackendStatus(json['status']),
      vendor: vendor,
      createdAt: created,
      items: const <StockEntryLineItem>[],
      payment: StockEntryPayment(
        totalPayment: total,
        paidAmount: paid,
        deadline: null,
      ),
    );
  }

  Future<({List<StockEntry> items, bool hasMore})> fetchStockEntryHistoryPage({
    required Vendor vendor,
    required int page,
    int pageSize = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (status != null && status.trim().isNotEmpty) {
      qp['status'] = status.trim().toLowerCase();
    }
    if (startDate != null) {
      qp['start_date'] = _ddMMyyyyDash(startDate);
    }
    if (endDate != null) {
      qp['end_date'] = _ddMMyyyyDash(endDate);
    }

    final response = await _apiService.get(
      _url(
        stockEntryHistoryListPath(vendor.id),
        queryParameters: qp,
      ).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load stock history (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic>? list;
    bool hasMore = false;

    if (decoded is List) {
      list = decoded;
      hasMore = false;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['data'] ?? decoded['results'] ?? decoded['items'];
      if (data is List) list = data;
      hasMore = decoded['next'] != null;
    }

    if (list == null) {
      throw const FormatException('Invalid stock history list response');
    }

    final out = <StockEntry>[];
    for (final row in list) {
      if (row is Map<String, dynamic>) {
        out.add(_historyEntryFromJson(row, vendor));
      }
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (items: out, hasMore: hasMore);
  }

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
    required Vendor vendor,
    required Map<String, dynamic> payload,
  }) async {
    final isExistingVendor = int.tryParse(vendor.id) != null;
    final path = isExistingVendor
        ? createExistingVendorStockEntryPath(vendor.id)
        : createNewVendorStockEntryPath;

    final response = await _apiService.post(
      _url(path).toString(),
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

  Future<List<StockEntry>> fetchStockEntryHistoryList({
    required Vendor vendor,
  }) async {
    final response = await _apiService.get(
      _url(stockEntryHistoryListPath(vendor.id)).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load stock history (${response.statusCode})',
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
      throw const FormatException('Invalid stock history list response');
    }

    final out = <StockEntry>[];
    for (final row in list) {
      if (row is Map<String, dynamic>) {
        out.add(_historyEntryFromJson(row, vendor));
      }
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
}
