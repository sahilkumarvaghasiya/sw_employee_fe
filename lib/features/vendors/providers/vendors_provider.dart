import 'dart:async';

import 'package:flutter/foundation.dart';
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
  int _requestGeneration = 0;
  Timer? _searchDebounce;

  VendorPaymentSummary get summary => _summary;
  List<VendorPayableGroup> get vendors => List.unmodifiable(_vendors);
  bool get isLoading => _isLoading;
  bool get isPaying => _isPaying;
  String? get error => _error;
  String get searchQuery => _searchQuery;

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
        ),
      ]);

      if (requestGeneration != _requestGeneration) return;

      _summary = results[0] as VendorPaymentSummary;
      _openBills = results[1] as List<VendorBill>;
      _vendors = _groupByVendor(_openBills);
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;
      _error = 'Failed to load vendors';
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
        (sum, b) => sum + (b.isFullyPaid ? 0 : b.pendingAmount),
      );
      return VendorPayableGroup(
        vendorName: entry.key,
        pendingAmount: pending,
        pendingDisplay: _inr.format(pending),
        bills: List.unmodifiable(vendorBills),
      );
    }).toList();

    // Pending vendors first; zero-balance vendors stay listed at the bottom.
    groups.sort((a, b) {
      final byPending = b.pendingAmount.compareTo(a.pendingAmount);
      if (byPending != 0) return byPending;
      return a.vendorName.toLowerCase().compareTo(b.vendorName.toLowerCase());
    });
    return groups;
  }

  void setSearchQuery(String value) {
    _searchQuery = value.trim();
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      refresh();
    });
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
    int? vendorId,
  }) {
    return _service.fetchReportPreview(
      startDate: startDate,
      endDate: endDate,
      vendorId: vendorId,
    );
  }

  Future<List<int>> fetchReportPdf({
    DateTime? startDate,
    DateTime? endDate,
    int? vendorId,
  }) async {
    final bytes = await _service.fetchReportPdf(
      startDate: startDate,
      endDate: endDate,
      vendorId: vendorId,
    );
    return bytes;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
