import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/utils/product_size_format.dart';
import '../../auth/services/api_service.dart';
import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../models/stock_entry_detail.dart';

class GeneratedBarcode {
  const GeneratedBarcode({required this.barcode, required this.barcodeUrl});

  final String barcode;
  final String barcodeUrl;
}

class StockOptionPage {
  const StockOptionPage({required this.items, required this.hasMore});

  final List<String> items;
  final bool hasMore;
}

@immutable
class StockBrandOption {
  const StockBrandOption({required this.id, required this.name});

  final String id;
  final String name;
}

class StockBrandPage {
  const StockBrandPage({required this.items, required this.hasMore});

  final List<StockBrandOption> items;
  final bool hasMore;
}

@immutable
class StockItemTypeOption {
  const StockItemTypeOption({required this.id, required this.name});

  final int id;
  final String name;
}

class StockItemTypePage {
  const StockItemTypePage({required this.items, required this.hasMore});

  final List<StockItemTypeOption> items;
  final bool hasMore;
}

@immutable
class StockSizeOption {
  const StockSizeOption({required this.id, required this.name});

  final int id;
  final String name;
}

class StockSizePage {
  const StockSizePage({required this.items, required this.hasMore});

  final List<StockSizeOption> items;
  final bool hasMore;
}

@immutable
class StockColourOption {
  const StockColourOption({required this.id, required this.name});

  final int id;
  final String name;
}

class StockColourPage {
  const StockColourPage({required this.items, required this.hasMore});

  final List<StockColourOption> items;
  final bool hasMore;
}

class StockEntryService {
  StockEntryService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  // Backend routes (baseUrl already includes `/api`).
  // From vendors app URLs:
  // POST /api/vendors/stock/generate-barcode/
  static const String generateBarcodePath = '/vendors/stock/generate-barcode/';
  static const String brandListPath = '/products/brands/list/';
  static const String itemTypesListPath = '/products/item-types/list/';
  static const String sizesListPath = '/products/sizes/list/';
  static const String coloursListPath = '/products/colors/list/';

  // From curl:
  // POST /api/vendors/stock/create/                (new vendor)
  // POST /api/vendors/existing/<int:id>/stock/create/ (existing vendor)
  static const String createNewVendorStockEntryPath = '/vendors/stock/create/';
  static const String validateVendorPath = '/vendors/validate/';
  static String createExistingVendorStockEntryPath(String vendorId) {
    final safeId = Uri.encodeComponent(vendorId);
    return '/vendors/existing/$safeId/stock/create/';
  }

  // From curl:
  // /api/vendors/stock/history/details/?stk_number=...
  static const String stockEntryDetailPath = '/vendors/stock/history/details/';

  // From curl:
  // /api/vendors/stock/<vendorId>/history/list/
  static String stockEntryHistoryListPath(String vendorId) {
    final safeId = Uri.encodeComponent(vendorId);
    return '/vendors/stock/$safeId/history/list/';
  }

  // Paginated options endpoint for add-item dropdowns.
  static const String stockEntryOptionsPath = '/vendors/stock/options/';

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
        (json['stk_number'] ?? json['invoiceNo'] ?? json['invoice'])
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
      stknumber: invoice?.trim().isEmpty ?? true ? null : invoice?.trim(),
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

  List<String> _extractOptionStrings(Object? raw) {
    if (raw is! List) return const <String>[];

    final out = <String>[];
    final seen = <String>{};

    void addValue(Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return;
      final key = text.toLowerCase();
      if (seen.add(key)) out.add(text);
    }

    for (final entry in raw) {
      if (entry is String || entry is num) {
        addValue(entry);
        continue;
      }
      if (entry is Map<String, dynamic>) {
        addValue(
          entry['name'] ??
              entry['label'] ??
              entry['value'] ??
              entry['title'] ??
              entry['item_type'] ??
              entry['product_type'] ??
              entry['company_name'] ??
              entry['size'] ??
              entry['colour'] ??
              entry['color'],
        );
      }
    }

    return out;
  }

  List<Map<String, dynamic>> _extractBrandRecords(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    final dynamic listValue = map['results'] ?? map['data'] ?? map['items'];
    if (listValue is List) {
      return listValue
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return [map];
  }

  bool _brandHasMore(dynamic decoded, int itemCount, int pageSize, int page) {
    if (decoded is! Map) return itemCount >= pageSize;
    final map = Map<String, dynamic>.from(decoded);
    if (map['next'] != null) return true;

    final totalPages = int.tryParse('${map['total_pages'] ?? ''}');
    if (totalPages != null && totalPages > 0) {
      return page < totalPages;
    }

    final count = map['count'];
    if (count is num) {
      return page * pageSize < count.toInt();
    }

    return itemCount >= pageSize;
  }

  StockBrandOption? _brandFromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString().trim();
    final name = (map['name'] ?? map['label'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) return null;
    return StockBrandOption(id: id, name: name);
  }

  StockItemTypeOption? _itemTypeFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = (map['name'] ?? '').toString().trim();
    if (id is! int || name.isEmpty) return null;
    return StockItemTypeOption(id: id, name: name);
  }

  bool _itemTypeHasMore(
    dynamic decoded,
    int itemCount,
    int pageSize,
    int page,
  ) {
    if (decoded is! Map) return itemCount >= pageSize;
    final map = Map<String, dynamic>.from(decoded);
    if (map['next'] != null) return true;

    final totalPages = int.tryParse('${map['total_pages'] ?? ''}');
    if (totalPages != null && totalPages > 0) {
      return page < totalPages;
    }

    final count = map['count'];
    if (count is num) {
      return page * pageSize < count.toInt();
    }

    return itemCount >= pageSize;
  }

  StockSizeOption? _sizeFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = (map['name'] ?? '').toString().trim();
    if (id is! int || name.isEmpty) return null;
    return StockSizeOption(id: id, name: formatProductSize(name));
  }

  bool _sizeHasMore(dynamic decoded, int itemCount, int pageSize, int page) {
    if (decoded is! Map) return itemCount >= pageSize;
    final map = Map<String, dynamic>.from(decoded);
    if (map['next'] != null) return true;

    final totalPages = int.tryParse('${map['total_pages'] ?? ''}');
    if (totalPages != null && totalPages > 0) {
      return page < totalPages;
    }

    final count = map['count'];
    if (count is num) {
      return page * pageSize < count.toInt();
    }

    return itemCount >= pageSize;
  }

  StockColourOption? _colourFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = (map['name'] ?? '').toString().trim();
    if (id is! int || name.isEmpty) return null;
    return StockColourOption(id: id, name: name);
  }

  bool _colourHasMore(dynamic decoded, int itemCount, int pageSize, int page) {
    if (decoded is! Map) return itemCount >= pageSize;
    final map = Map<String, dynamic>.from(decoded);
    if (map['next'] != null) return true;

    final totalPages = int.tryParse('${map['total_pages'] ?? ''}');
    if (totalPages != null && totalPages > 0) {
      return page < totalPages;
    }

    final count = map['count'];
    if (count is num) {
      return page * pageSize < count.toInt();
    }

    return itemCount >= pageSize;
  }

  Future<StockOptionPage> fetchStockOptionPage({
    required String option,
    required int page,
    int pageSize = 30,
    String? search,
  }) async {
    final query = (search ?? '').trim();
    final qp = <String, String>{
      'option': option,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query.isNotEmpty) {
      qp['search'] = query;
      qp['query'] = query;
    }

    final response = await _apiService.get(
      _url(stockEntryOptionsPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load $option options (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    List<String> list = const <String>[];
    bool hasMore = false;

    if (decoded is List) {
      list = _extractOptionStrings(decoded);
      hasMore = list.length >= pageSize;
    } else if (decoded is Map<String, dynamic>) {
      final topLevel =
          decoded['results'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['options'];

      if (topLevel is List) {
        list = _extractOptionStrings(topLevel);
      } else if (topLevel is Map<String, dynamic>) {
        final nested =
            topLevel['results'] ??
            topLevel['data'] ??
            topLevel['items'] ??
            topLevel['options'];
        list = _extractOptionStrings(nested);
      }

      final next = decoded['next'];
      if (next != null) {
        hasMore = true;
      } else {
        final totalPages = int.tryParse('${decoded['total_pages'] ?? ''}');
        if (totalPages != null && totalPages > 0) {
          hasMore = page < totalPages;
        } else {
          hasMore = list.length >= pageSize;
        }
      }
    }

    return StockOptionPage(items: list, hasMore: hasMore);
  }

  Future<StockBrandPage> fetchBrandOptionsPage({
    required int page,
    int pageSize = 30,
    String? search,
  }) async {
    final query = (search ?? '').trim();
    final qp = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query.isNotEmpty) {
      qp['search'] = query;
    }

    final response = await _apiService.get(
      _url(brandListPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load brand options (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractBrandRecords(decoded);
    final items = records
        .map(_brandFromMap)
        .where((item) => item != null)
        .cast<StockBrandOption>()
        .toList();
    final hasMore = _brandHasMore(decoded, items.length, pageSize, page);

    return StockBrandPage(items: items, hasMore: hasMore);
  }

  Future<StockItemTypePage> fetchItemTypeOptionsPage({
    required int page,
    int pageSize = 30,
    String? search,
  }) async {
    final query = (search ?? '').trim();
    final qp = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query.isNotEmpty) {
      qp['search'] = query;
    }

    final response = await _apiService.get(
      _url(itemTypesListPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load item type options (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractBrandRecords(decoded);
    final items = records
        .map(_itemTypeFromMap)
        .where((item) => item != null)
        .cast<StockItemTypeOption>()
        .toList();
    final hasMore = _itemTypeHasMore(decoded, items.length, pageSize, page);

    return StockItemTypePage(items: items, hasMore: hasMore);
  }

  Future<StockSizePage> fetchSizeOptionsPage({
    required int page,
    int pageSize = 30,
    String? search,
  }) async {
    final query = (search ?? '').trim();
    final qp = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query.isNotEmpty) {
      qp['search'] = query;
    }

    final response = await _apiService.get(
      _url(sizesListPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load size options (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractBrandRecords(decoded);
    final items = records
        .map(_sizeFromMap)
        .where((item) => item != null)
        .cast<StockSizeOption>()
        .toList();
    final hasMore = _sizeHasMore(decoded, items.length, pageSize, page);

    return StockSizePage(items: items, hasMore: hasMore);
  }

  Future<StockColourPage> fetchColourOptionsPage({
    required int page,
    int pageSize = 30,
    String? search,
  }) async {
    final query = (search ?? '').trim();
    final qp = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query.isNotEmpty) {
      qp['search'] = query;
    }

    final response = await _apiService.get(
      _url(coloursListPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load colour options (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractBrandRecords(decoded);
    final items = records
        .map(_colourFromMap)
        .where((item) => item != null)
        .cast<StockColourOption>()
        .toList();
    final hasMore = _colourHasMore(decoded, items.length, pageSize, page);

    return StockColourPage(items: items, hasMore: hasMore);
  }

  Future<GeneratedBarcode> generateBarcode({
    required String companyName,
    required String productType,
    required String gender,
    required List<Map<String, dynamic>> itemVariants,
  }) async {
    final response = await _apiService.post(
      _url(generateBarcodePath).toString(),
      body: <String, dynamic>{
        'company_name': companyName,
        'product_type': productType,
        'gender': gender,
        'item_variants': itemVariants,
      },
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

    final barcode =
        (decoded['barcode_number'] ??
                decoded['barcode'] ??
                decoded['barcode_number'])
            ?.toString()
            .trim();
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
              decoded['stk_number'] ??
              decoded['invoiceNo'] ??
              decoded['invoice'];

          final data = decoded['data'];
          if ((invoice == null || invoice.toString().trim().isEmpty) &&
              data is Map<String, dynamic>) {
            invoice =
                data['stk_number'] ?? data['invoiceNo'] ?? data['invoice'];
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

  Future<void> validateVendor({
    required String name,
    required String phone,
    String? email,
    String? gst,
  }) async {
    final response = await _apiService.post(
      _url(validateVendorPath).toString(),
      body: <String, dynamic>{
        'vendor_name': name.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim(),
        if (gst != null && gst.trim().isNotEmpty) 'gst_number': gst.trim(),
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message =
        'Failed to validate vendor (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value =
            decoded['message'] ?? decoded['detail'] ?? decoded['error'];
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
    required String stknumber,
  }) async {
    final response = await _apiService.get(
      _url(
        stockEntryDetailPath,
        queryParameters: {'stk_number': stknumber},
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
