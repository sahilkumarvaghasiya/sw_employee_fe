import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/vendor_bill.dart';
import '../services/vendors_payments_service.dart';

/// TODO(remove): Dummy bill detail/pay helpers only — listing uses live API.
const bool kUsePayVendorDummyData = true;

class VendorsProvider extends ChangeNotifier {
  VendorsProvider({VendorsPaymentsService? service})
    : _service = service ?? VendorsPaymentsService();

  final VendorsPaymentsService _service;

  static const int _pageSize = 15;

  VendorPaymentSummary _summary = VendorPaymentSummary.empty;
  List<VendorPayableGroup> _vendors = const <VendorPayableGroup>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isPaying = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _searchQuery = '';
  int _requestGeneration = 0;
  Timer? _searchDebounce;

  VendorPaymentSummary get summary => _summary;
  List<VendorPayableGroup> get vendors => List.unmodifiable(_vendors);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isPaying => _isPaying;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  Future<void> refresh() async {
    final requestGeneration = ++_requestGeneration;
    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    _page = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchSummary(),
        _service.fetchPayableVendorsPage(
          search: _searchQuery,
          page: 1,
          pageSize: _pageSize,
        ),
      ]);

      if (requestGeneration != _requestGeneration) return;

      _summary = results[0] as VendorPaymentSummary;
      final page = results[1] as VendorPayableVendorsPage;
      _vendors = page.vendors;
      _hasMore = page.hasNext;
      _page = 2;
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;
      _error = 'Failed to load vendors';
      _vendors = const <VendorPayableGroup>[];
      _hasMore = false;
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    final requestGeneration = _requestGeneration;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.fetchPayableVendorsPage(
        search: _searchQuery,
        page: _page,
        pageSize: _pageSize,
      );

      if (requestGeneration != _requestGeneration) return;

      _vendors = [..._vendors, ...page.vendors];
      _hasMore = page.hasNext;
      _page += 1;
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;
      // Keep existing list; user can scroll again to retry.
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Loads open bills for a vendor when opening detail (list API has no bill rows).
  Future<VendorPayableGroup> ensureVendorBills(VendorPayableGroup group) async {
    if (group.bills.isNotEmpty) return group;

    final key = group.vendorName.trim().toLowerCase();
    final bills = await _service.fetchOpenBills(search: group.vendorName);
    final matched = bills
        .where((b) => b.vendor.trim().toLowerCase() == key)
        .toList(growable: false);

    final updated = group.copyWith(bills: matched);
    final index = _vendors.indexWhere(
      (v) => v.vendorName.trim().toLowerCase() == key,
    );
    if (index >= 0) {
      final next = [..._vendors];
      next[index] = updated;
      _vendors = next;
      notifyListeners();
    }
    return updated;
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
    // TODO(remove): Serve dummy bill details locally.
    if (kUsePayVendorDummyData) {
      for (final bill in _dummyOpenBills(search: '')) {
        if (bill.id == id) return Future.value(bill);
      }
    }
    return _service.fetchBill(id);
  }

  Future<VendorPayablePayResult> payVendorBills({
    required int vendorId,
    required List<int> billIds,
    required double amount,
    double discount = 0,
    double surcharge = 0,
    DateTime? paymentDate,
  }) async {
    _isPaying = true;
    notifyListeners();

    try {
      final result = await _service.payVendorBills(
        vendorId: vendorId,
        billIds: billIds,
        amount: amount,
        discount: discount,
        surcharge: surcharge,
        paymentDate: paymentDate,
      );
      await refresh();
      return result;
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

  /// TODO(remove): Dummy bills for detail/pay testing only.
  static List<VendorBill> _dummyOpenBills({required String search}) {
    final query = search.trim().toLowerCase();

    const pendingVendor = 'Demo Traders (Dummy)';
    const settledVendor = 'Settled Supplies (Dummy)';

    const all = [
      VendorBill(
        id: -9001,
        vendor: pendingVendor,
        stkNo: 'STK-DUMMY-001',
        billDate: '20 Jul 2026',
        totalDisplay: '12,500.00',
        paidDisplay: '2,500.00',
        pendingDisplay: '10,000.00',
        statusDisplay: 'Partial',
        due: VendorDueInfo(label: 'Due in 3 days', state: 'due', days: 3),
        stockLines: [
          VendorStockLine(itemType: 'Shirt', brand: 'DemoBrand', qty: 20),
          VendorStockLine(itemType: 'Trouser', brand: 'DemoBrand', qty: 10),
        ],
      ),
      VendorBill(
        id: -9002,
        vendor: pendingVendor,
        stkNo: 'STK-DUMMY-002',
        billDate: '15 Jul 2026',
        totalDisplay: '5,000.00',
        paidDisplay: '0.00',
        pendingDisplay: '5,000.00',
        statusDisplay: 'Unpaid',
        due: VendorDueInfo(label: 'Overdue by 2 days', state: 'overdue', days: 2),
        stockLines: [
          VendorStockLine(itemType: 'T-Shirt', brand: 'DemoBrand', qty: 40),
        ],
      ),
      VendorBill(
        id: -9003,
        vendor: settledVendor,
        stkNo: 'STK-DUMMY-003',
        billDate: '01 Jul 2026',
        totalDisplay: '3,000.00',
        paidDisplay: '3,000.00',
        pendingDisplay: '0.00',
        statusDisplay: 'Paid',
        due: VendorDueInfo(label: 'Paid', state: 'paid'),
        stockLines: [
          VendorStockLine(itemType: 'Cap', brand: 'DemoBrand', qty: 15),
        ],
      ),
    ];

    if (query.isEmpty) return all;
    return all
        .where((b) => b.vendor.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
