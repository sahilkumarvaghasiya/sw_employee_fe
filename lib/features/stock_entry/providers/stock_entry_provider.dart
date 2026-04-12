import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/stock_entry.dart';
import '../models/vendor.dart';

class StockEntryProvider extends ChangeNotifier {
  StockEntryProvider() {
    _seedDummyData();
    _loadInitial();
  }

  static const int _pageSize = 12;

  final List<Vendor> _vendors = [];
  final List<StockEntry> _allEntries = [];

  final List<StockEntry> _visibleEntries = [];

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;

  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  List<Vendor> get vendors => List.unmodifiable(_vendors);
  List<StockEntry> get entries => List.unmodifiable(_visibleEntries);

  bool get hasMore => _visibleEntries.length < _allEntries.length;

  Vendor? vendorById(String id) {
    try {
      return _vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  void addVendor(Vendor vendor) {
    _vendors.insert(0, vendor);
    notifyListeners();
  }

  void addStockEntry(StockEntry entry) {
    _allEntries.insert(0, entry);
    _visibleEntries.insert(0, entry);
    notifyListeners();
  }

  Future<void> saveStockEntry(StockEntry entry) async {
    if (vendorById(entry.vendor.id) == null) {
      _vendors.insert(0, entry.vendor);
    }
    addStockEntry(entry);
  }

  Future<void> refreshHistory() async {
    _error = null;
    _visibleEntries.clear();

    notifyListeners();
    await _loadInitial();
  }

  Future<void> loadMoreHistory() async {
    if (_isLoadingMore || _isLoadingInitial) return;
    if (!hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final start = _visibleEntries.length;
      final end = (start + _pageSize).clamp(0, _allEntries.length);
      _visibleEntries.addAll(_allEntries.sublist(start, end));
    } catch (e) {
      _error = 'Unable to load more history.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadInitial() async {
    _isLoadingInitial = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _visibleEntries.clear();
      _visibleEntries.addAll(_allEntries.take(_pageSize));
    } catch (_) {
      _error = 'Unable to load history.';
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  void _seedDummyData() {
    _vendors.addAll([
      const Vendor(
        id: 'v_1',
        name: 'Shree Traders',
        phone: '9876543210',
        email: null,
        address: '12, Market Road, Pune',
        gst: '27AAAAA0000A1Z5',
      ),
      const Vendor(
        id: 'v_2',
        name: 'Kaveri Distributors',
        phone: '9123456780',
        email: 'kaveri@example.com',
        address: 'Near Bus Stand, Nashik',
        gst: '27BBBBB0000B1Z5',
      ),
      const Vendor(
        id: 'v_3',
        name: 'Omkar Wholesale',
        phone: '9988776655',
        email: null,
        address: 'Industrial Area, Mumbai',
        gst: '27CCCCC0000C1Z5',
      ),
    ]);

    final now = DateTime.now();

    _allEntries.addAll([
      StockEntry(
        id: 'se_1003',
        invoiceNumber: 'INV-1003',
        vendor: _vendors[0],
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        items: const [
          StockEntryLineItem(
            productId: 'p_101',
            productName: 'Parle-G 250g',
            quantity: 24,
            costPrice: 18.0,
            sellingPrice: 20.0,
          ),
          StockEntryLineItem(
            productId: 'p_112',
            productName: 'Aashirvaad Atta 5kg',
            quantity: 6,
            costPrice: 250.0,
            sellingPrice: 275.0,
          ),
        ],
        payment: const StockEntryPayment(
          totalPayment: 24 * 18.0 + 6 * 250.0,
          paidAmount: 1000.0,
          deadline: null,
        ),
      ),
      StockEntry(
        id: 'se_1002',
        invoiceNumber: 'INV-1002',
        vendor: _vendors[1],
        createdAt: now.subtract(const Duration(days: 3, hours: 2)),
        items: const [
          StockEntryLineItem(
            productId: 'p_205',
            productName: 'Coca-Cola 750ml',
            quantity: 12,
            costPrice: 32.0,
            sellingPrice: 40.0,
          ),
          StockEntryLineItem(
            productId: 'p_207',
            productName: 'Sprite 750ml',
            quantity: 12,
            costPrice: 32.0,
            sellingPrice: 40.0,
          ),
        ],
        payment: const StockEntryPayment(
          totalPayment: 768.0,
          paidAmount: 768.0,
          deadline: null,
        ),
      ),
      StockEntry(
        id: 'se_1001',
        invoiceNumber: 'INV-1001',
        vendor: _vendors[2],
        createdAt: now.subtract(const Duration(days: 6, hours: 6)),
        items: const [
          StockEntryLineItem(
            productId: 'p_309',
            productName: 'Lux Soap',
            quantity: 48,
            costPrice: 28.0,
            sellingPrice: 35.0,
          ),
        ],
        payment: const StockEntryPayment(
          totalPayment: 1344.0,
          paidAmount: 0.0,
          deadline: null,
        ),
      ),
    ]);

    _allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
