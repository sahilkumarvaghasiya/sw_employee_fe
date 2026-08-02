import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/vendor_bill.dart';

class VendorsPaymentsService {
  VendorsPaymentsService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String _summaryPath = '/vendors/payable/summary/';
  static const String _payableVendorsPath = '/vendors/payable/vendors/';
  static const String _billsPath = '/manager/vendors/bills/';
  // Employee payable report (default last 6 months when dates empty).
  static const String _reportPreviewPath = '/vendors/payable/reports/preview/';
  static const String _reportPdfPath = '/vendors/payable/reports/pdf/';

  static String _payableVendorInfoPath(int vendorId) =>
      '/vendors/payable/vendors/$vendorId/info/';

  static String _payableVendorPendingPath(int vendorId) =>
      '/vendors/payable/vendors/$vendorId/pending/';

  static String _payableBillDetailPath(int billId) =>
      '/vendors/payable/bills/$billId/';

  static String _payableVendorPayPath(int vendorId) =>
      '/vendors/payable/vendors/$vendorId/pay/';

  static String _payableVendorStatementPath(int vendorId) =>
      '/vendors/payable/vendors/$vendorId/statement/';

  static String _payablePaymentDetailPath(int paymentId) =>
      '/vendors/payable/payments/$paymentId/';

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

  static String ddMMyyyyDash(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  Future<VendorPaymentSummary> fetchSummary() async {
    final response = await _apiService.get(_url(_summaryPath).toString());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load vendor summary (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid vendor summary response');
    }
    return VendorPaymentSummary.fromJson(decoded);
  }

  /// Pay Vendor hub list — one page (size from BE `VendorPayableVendorsPagination`).
  Future<VendorPayableVendorsPage> fetchPayableVendorsPage({
    String? search,
    int page = 1,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
    };
    final query = (search ?? '').trim();
    if (query.isNotEmpty) qp['search'] = query;

    final response = await _apiService.get(
      _url(_payableVendorsPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load payable vendors (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    List<dynamic>? rows;
    bool hasNext = false;
    var count = 0;

    if (decoded is List) {
      rows = decoded;
      count = decoded.length;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['results'] ?? decoded['data'] ?? decoded['items'];
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
      throw const FormatException('Invalid payable vendors response');
    }

    final vendors = rows
        .whereType<Map>()
        .map(
          (e) => VendorPayableGroup.fromPayableApi(
            e.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);

    return VendorPayableVendorsPage(
      vendors: vendors,
      hasNext: hasNext,
      count: count,
    );
  }

  Future<Map<String, dynamic>> fetchPayableVendorInfo(int vendorId) async {
    final response = await _apiService.get(
      _url(_payableVendorInfoPath(vendorId)).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load vendor info (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid vendor info response');
    }
    return decoded;
  }

  /// One page of pending bills (page size from BE, currently 20).
  Future<VendorBillsPage> fetchPayablePendingBillsPage({
    required int vendorId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
    };
    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);

    final response = await _apiService.get(
      _url(
        _payableVendorPendingPath(vendorId),
        queryParameters: qp,
      ).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load pending bills (${response.statusCode})',
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
      final data = decoded['results'] ?? decoded['data'] ?? decoded['items'];
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
      throw const FormatException('Invalid pending bills response');
    }

    final bills = rows
        .whereType<Map>()
        .map((e) => VendorBill.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);

    return VendorBillsPage(bills: bills, hasNext: hasNext, count: count);
  }

  Future<VendorBillsPage> fetchBills({
    String? search,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String sort = 'newest',
    int page = 1,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
    };

    final query = (search ?? '').trim();
    if (query.isNotEmpty) qp['search'] = query;

    final statusValue = (status ?? '').trim().toLowerCase();
    if (statusValue.isNotEmpty && statusValue != 'all') {
      qp['status'] = statusValue;
    }

    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);
    if (sort == 'oldest') qp['sort'] = 'oldest';

    final response = await _apiService.get(
      _url(_billsPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load vendor bills (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic>? rows;
    bool hasNext = false;
    int count = 0;

    if (decoded is List) {
      rows = decoded;
      count = decoded.length;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['results'] ?? decoded['data'] ?? decoded['items'];
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
      throw const FormatException('Invalid vendor bills response');
    }

    final bills = rows
        .whereType<Map>()
        .map((e) => VendorBill.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);

    return VendorBillsPage(bills: bills, hasNext: hasNext, count: count);
  }

  /// Loads bills for the Pay Vendor hub (all statuses) so settled vendors stay listed.
  /// Search is the only filter applied here.
  Future<List<VendorBill>> fetchOpenBills({
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bills = <VendorBill>[];
    var page = 1;
    while (true) {
      final result = await fetchBills(
        search: search,
        startDate: startDate,
        endDate: endDate,
        sort: 'newest',
        page: page,
      );
      bills.addAll(result.bills);
      if (!result.hasNext) break;
      page += 1;
      if (page > 50) break; // safety cap
    }

    return bills;
  }

  Future<VendorBill> fetchBill(int id) async {
    final response = await _apiService.get(
      _url(_payableBillDetailPath(id)).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load vendor bill (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid vendor bill response');
    }
    return VendorBill.fromJson(decoded);
  }

  Future<VendorPayablePayResult> payVendorBills({
    required int vendorId,
    required List<int> billIds,
    required double amount,
    double discount = 0,
    double surcharge = 0,
    DateTime? paymentDate,
  }) async {
    final body = <String, dynamic>{
      'bill_ids': billIds,
      'amount': amount,
      'discount': discount,
      'surcharge': surcharge,
    };
    if (paymentDate != null) {
      body['payment_date'] = ddMMyyyyDash(paymentDate);
    }

    final response = await _apiService.post(
      _url(_payableVendorPayPath(vendorId)).toString(),
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractErrorMessage(response) ??
          'Failed to allocate payment (${response.statusCode})';
      throw http.ClientException(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment response');
    }

    final paymentRaw = decoded['payment'];
    if (paymentRaw is! Map) {
      throw const FormatException('Invalid payment payload');
    }

    final billsRaw = decoded['bills'];
    final bills = <VendorBill>[];
    if (billsRaw is List) {
      bills.addAll(
        billsRaw
            .whereType<Map>()
            .map((e) => VendorBill.fromJson(e.cast<String, dynamic>())),
      );
    }

    return VendorPayablePayResult(
      payment: VendorStatementPayment.fromPaymentApi(
        paymentRaw.cast<String, dynamic>(),
      ),
      bills: bills,
    );
  }

  /// One page of statement rows (page size from BE, currently 20).
  Future<VendorStatementPage> fetchPayableStatementPage({
    required int vendorId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
    };
    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);

    final response = await _apiService.get(
      _url(
        _payableVendorStatementPath(vendorId),
        queryParameters: qp,
      ).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load statement (${response.statusCode})',
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
      final data = decoded['results'] ?? decoded['data'];
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
      throw const FormatException('Invalid statement response');
    }

    final entries = <VendorStatementEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = row.cast<String, dynamic>();
      final kind = (map['kind'] ?? '').toString().toLowerCase();
      final sortRaw = (map['sort_at'] ?? '').toString();
      final parsedSort = DateTime.tryParse(sortRaw);
      final sortAt = parsedSort == null
          ? DateTime.now()
          : (parsedSort.isUtc ? parsedSort.toLocal() : parsedSort);

      if (kind == 'payment') {
        final paymentRaw = map['payment'];
        if (paymentRaw is! Map) continue;
        entries.add(
          VendorStatementEntry.payment(
            payment: VendorStatementPayment.fromPaymentApi(
              paymentRaw.cast<String, dynamic>(),
            ),
            sortAt: sortAt,
          ),
        );
      } else if (kind == 'purchase') {
        final billRaw = map['bill'];
        if (billRaw is! Map) continue;
        entries.add(
          VendorStatementEntry.purchase(
            bill: VendorBill.fromJson(billRaw.cast<String, dynamic>()),
            sortAt: sortAt,
          ),
        );
      }
    }
    return VendorStatementPage(
      entries: List.unmodifiable(entries),
      hasNext: hasNext,
      count: count,
    );
  }

  Future<VendorStatementPayment> fetchPayablePaymentDetail(int paymentId) async {
    final response = await _apiService.get(
      _url(_payablePaymentDetailPath(paymentId)).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load payment details (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment detail response');
    }
    return VendorStatementPayment.fromPaymentApi(decoded);
  }

  @Deprecated('Use payVendorBills')
  Future<List<VendorBill>> bulkPay({
    required List<int> billIds,
    required double amount,
  }) async {
    final response = await _apiService.post(
      _url('${_billsPath}bulk-pay/').toString(),
      body: {
        'bill_ids': billIds,
        'amount': amount,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractErrorMessage(response) ??
          'Failed to allocate payment (${response.statusCode})';
      throw http.ClientException(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid bulk payment response');
    }

    final billsRaw = decoded['bills'];
    if (billsRaw is! List) {
      throw const FormatException('Invalid bulk payment bills payload');
    }

    return billsRaw
        .whereType<Map>()
        .map((e) => VendorBill.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<VendorReportPreview> fetchReportPreview({
    DateTime? startDate,
    DateTime? endDate,
    int? vendorId,
  }) async {
    final qp = <String, String>{};
    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);
    if (vendorId != null) qp['vendor'] = vendorId.toString();

    final response = await _apiService.get(
      _url(_reportPreviewPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load report preview (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid report preview response');
    }
    return VendorReportPreview.fromJson(decoded);
  }

  Future<Uint8List> fetchReportPdf({
    DateTime? startDate,
    DateTime? endDate,
    int? vendorId,
  }) async {
    final qp = <String, String>{};
    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);
    if (vendorId != null) qp['vendor'] = vendorId.toString();

    final response = await _apiService.get(
      _url(_reportPdfPath, queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to download report PDF (${response.statusCode})',
      );
    }

    return response.bodyBytes;
  }

  Future<Uint8List> fetchStatementPdf({
    required int vendorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, String>{'export': 'pdf'};
    if (startDate != null) qp['start_date'] = ddMMyyyyDash(startDate);
    if (endDate != null) qp['end_date'] = ddMMyyyyDash(endDate);

    final response = await _apiService.get(
      _url(_payableVendorStatementPath(vendorId), queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to download statement PDF (${response.statusCode})',
      );
    }

    return response.bodyBytes;
  }

  String? _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();

      final amount = map['amount'];
      if (amount is List && amount.isNotEmpty) {
        return amount.first.toString();
      }
      if (amount is String && amount.trim().isNotEmpty) {
        return amount;
      }

      final billIds = map['bill_ids'];
      if (billIds is List && billIds.isNotEmpty) {
        return billIds.first.toString();
      }
      if (billIds is String && billIds.trim().isNotEmpty) {
        return billIds;
      }

      final detail = map['detail'] ?? map['message'] ?? map['error'];
      if (detail is List && detail.isNotEmpty) {
        return detail.first.toString();
      }
      if (detail != null) {
        final text = detail.toString().trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
