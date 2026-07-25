import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/vendor_bill.dart';
import '../services/vendors_payments_service.dart';

/// TODO(remove): Temporary Pay Vendor dummy data for UI testing until API is ready.
const bool kUsePayVendorDummyData = true;

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

      var summary = results[0] as VendorPaymentSummary;
      var openBills = results[1] as List<VendorBill>;

      // TODO(remove): Inject dummy Pay Vendor entry for testing.
      if (kUsePayVendorDummyData) {
        final dummy = _dummyOpenBills(search: _searchQuery);
        openBills = [...openBills, ...dummy];
        summary = _mergeSummaryWithDummy(summary, dummy);
      }

      _summary = summary;
      _openBills = openBills;
      _vendors = _groupByVendor(_openBills);
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;

      // TODO(remove): Keep dummy visible even when API fails.
      if (kUsePayVendorDummyData) {
        final dummy = _dummyOpenBills(search: _searchQuery);
        _openBills = dummy;
        _vendors = _groupByVendor(_openBills);
        _summary = _mergeSummaryWithDummy(VendorPaymentSummary.empty, dummy);
        _error = null;
      } else {
        _error = 'Failed to load vendors';
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// TODO(remove): Dummy bills used only while Pay Vendor API is incomplete.
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
      // Zero-balance vendor — must remain on the Pay Vendor list.
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

  static VendorPaymentSummary _mergeSummaryWithDummy(
    VendorPaymentSummary base,
    List<VendorBill> dummy,
  ) {
    final openDummy =
        dummy.where((b) => !b.isFullyPaid && b.pendingAmount > 0).toList();
    if (openDummy.isEmpty) return base;
    final dummyPending = openDummy.fold<double>(
      0,
      (sum, bill) => sum + bill.pendingAmount,
    );
    final basePending = parseIndianAmount(base.totalPendingDisplay) ?? 0;
    final overdueExtra = openDummy.where((b) => b.due.isOverdue).length;
    final dueSoonExtra = openDummy.where((b) => b.due.isDueSoon).length;

    return VendorPaymentSummary(
      totalPendingDisplay: _inr.format(basePending + dummyPending),
      pendingBills: base.pendingBills + openDummy.length,
      overdue: base.overdue + overdueExtra,
      dueThisWeek: base.dueThisWeek + dueSoonExtra,
    );
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
    // TODO(remove): Serve dummy bill details locally.
    if (kUsePayVendorDummyData) {
      for (final bill in _dummyOpenBills(search: '')) {
        if (bill.id == id) return Future.value(bill);
      }
    }
    return _service.fetchBill(id);
  }

  Future<List<VendorBill>> bulkPay({
    required List<int> billIds,
    required double amount,
  }) async {
    _isPaying = true;
    notifyListeners();

    try {
      // TODO(remove): Fake payment success for dummy bills.
      if (kUsePayVendorDummyData &&
          billIds.every((id) => id < 0) &&
          _openBills.any((b) => billIds.contains(b.id))) {
        final updated = <VendorBill>[];
        for (final bill in _openBills) {
          if (!billIds.contains(bill.id)) continue;
          updated.add(
            VendorBill(
              id: bill.id,
              vendor: bill.vendor,
              stkNo: bill.stkNo,
              billDate: bill.billDate,
              totalDisplay: bill.totalDisplay,
              paidDisplay: bill.pendingDisplay,
              pendingDisplay: '0.00',
              statusDisplay: 'Paid',
              due: const VendorDueInfo(label: 'Paid', state: 'paid'),
              stockLines: bill.stockLines,
            ),
          );
        }
        final updatedById = {for (final bill in updated) bill.id: bill};
        _openBills = [
          for (final bill in _openBills)
            if (updatedById.containsKey(bill.id))
              updatedById[bill.id]!
            else
              bill,
        ];
        _vendors = _groupByVendor(_openBills);
        _summary = _mergeSummaryWithDummy(
          VendorPaymentSummary.empty,
          _openBills.where((b) => b.id < 0 && !b.isFullyPaid).toList(),
        );
        return updated;
      }

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
