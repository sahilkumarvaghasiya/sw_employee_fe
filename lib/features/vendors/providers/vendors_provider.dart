import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vendor_bill.dart';
import '../services/vendors_payments_service.dart';

class VendorsProvider extends ChangeNotifier {
  VendorsProvider({VendorsPaymentsService? service})
    : _service = service ?? VendorsPaymentsService();

  final VendorsPaymentsService _service;
  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');

  VendorPaymentSummary _summary = VendorPaymentSummary.empty;
  List<VendorPayableGroup> _vendors = const <VendorPayableGroup>[];
  List<VendorBill> _openBills = const <VendorBill>[];
  bool _isLoading = false;
  bool _isPaying = false;
  String? _error;
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  int _requestGeneration = 0;

  VendorPaymentSummary get summary => _summary;
  List<VendorPayableGroup> get vendors => List.unmodifiable(_vendors);
  bool get isLoading => _isLoading;
  bool get isPaying => _isPaying;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  DateTimeRange? get dateRange => _dateRange;

  Future<void> refresh() async {
    final requestGeneration = ++_requestGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchSummary(),
        _service.fetchOpenBills(
          search: _searchQuery,
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        ),
      ]);

      if (requestGeneration != _requestGeneration) return;

      _summary = results[0] as VendorPaymentSummary;
      _openBills = results[1] as List<VendorBill>;
      _vendors = _groupByVendor(_openBills);
    } catch (_) {
      if (requestGeneration == _requestGeneration) {
        _error = 'Failed to load payables';
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  List<VendorPayableGroup> _groupByVendor(List<VendorBill> bills) {
    final map = <String, List<VendorBill>>{};

    for (final bill in bills) {
      if (bill.isFullyPaid || bill.pendingAmount <= 0) continue;
      final key = bill.vendor.trim().isEmpty
          ? 'Unknown'
          : bill.vendor.trim();
      map.putIfAbsent(key, () => <VendorBill>[]).add(bill);
    }

    final groups = map.entries.map((entry) {
      final vendorBills = entry.value
        ..sort((a, b) => b.billDate.compareTo(a.billDate));
      final pending = vendorBills.fold<double>(
        0,
        (sum, b) => sum + b.pendingAmount,
      );
      return VendorPayableGroup(
        vendorName: entry.key,
        pendingAmount: pending,
        pendingDisplay: _inr.format(pending),
        bills: List.unmodifiable(vendorBills),
      );
    }).toList();

    groups.sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));
    return groups;
  }

  Future<void> updateSearchQuery(String value) async {
    _searchQuery = value.trim();
    await refresh();
  }

  Future<void> setDateRange(DateTimeRange? range) async {
    _dateRange = range;
    await refresh();
  }

  VendorPayableGroup? vendorByName(String name) {
    final key = name.trim().toLowerCase();
    for (final v in _vendors) {
      if (v.vendorName.toLowerCase() == key) return v;
    }
    return null;
  }

  Future<VendorBill> fetchBill(int id) {
    return _service.fetchBill(id);
  }

  Future<VendorBill> recordPayment({
    required int billId,
    required double amount,
  }) async {
    _isPaying = true;
    notifyListeners();

    try {
      final updated = await _service.recordPayment(
        billId: billId,
        amount: amount,
      );

      _openBills = [
        for (final bill in _openBills)
          if (bill.id == billId) updated else bill,
      ];
      _vendors = _groupByVendor(_openBills);

      try {
        _summary = await _service.fetchSummary();
      } catch (_) {}

      return updated;
    } finally {
      _isPaying = false;
      notifyListeners();
    }
  }

  Future<List<VendorBill>> bulkPay({
    required List<int> billIds,
    required double amount,
  }) async {
    _isPaying = true;
    notifyListeners();

    try {
      final updatedBills = await _service.bulkPay(
        billIds: billIds,
        amount: amount,
      );

      final updatedById = {
        for (final bill in updatedBills) bill.id: bill,
      };

      _openBills = [
        for (final bill in _openBills)
          if (updatedById.containsKey(bill.id))
            updatedById[bill.id]!
          else
            bill,
      ];
      _vendors = _groupByVendor(_openBills);

      try {
        _summary = await _service.fetchSummary();
      } catch (_) {}

      return updatedBills;
    } finally {
      _isPaying = false;
      notifyListeners();
    }
  }

  Future<VendorReportPreview> fetchReportPreview({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _service.fetchReportPreview(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<int>> fetchReportPdf({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bytes = await _service.fetchReportPdf(
      startDate: startDate,
      endDate: endDate,
    );
    return bytes;
  }
}
