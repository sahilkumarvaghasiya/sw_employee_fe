import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../services/stock_entry_service.dart';
import '../services/vendors_service.dart';

class StockEntryProvider extends ChangeNotifier {
  StockEntryProvider({
    StockEntryService? stockEntryService,
    VendorsService? vendorsService,
  }) : _stockEntryService = stockEntryService ?? StockEntryService(),
       _vendorsService = vendorsService ?? VendorsService() {
    unawaited(refreshVendors());
  }

  final StockEntryService _stockEntryService;
  final VendorsService _vendorsService;

  final List<Vendor> _vendors = [];
  final List<StockEntry> _visibleEntries = [];

  int _historyPage = 1;
  bool _historyHasMore = true;
  String? _historyStatus;
  DateTimeRange? _historyDateRange;

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;

  bool _isLoadingVendors = false;
  String? _vendorsError;

  Vendor? _historyVendor;

  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  bool get isLoadingVendors => _isLoadingVendors;
  String? get vendorsError => _vendorsError;

  Vendor? get historyVendor => _historyVendor;

  List<Vendor> get vendors => List.unmodifiable(_vendors);
  List<StockEntry> get entries => List.unmodifiable(_visibleEntries);

  bool get hasMore => _historyHasMore;

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
    _visibleEntries.insert(0, entry);
    notifyListeners();
  }

  Future<void> saveStockEntry(StockEntry entry) async {
    if (vendorById(entry.vendor.id) == null) {
      _vendors.insert(0, entry.vendor);
    }

    // If the current history view is for this vendor, keep it in sync.
    if (_historyVendor?.id == entry.vendor.id) {
      addStockEntry(entry);
    }
  }

  Future<void> refreshVendors() async {
    if (_isLoadingVendors) return;

    _isLoadingVendors = true;
    _vendorsError = null;
    notifyListeners();

    try {
      final list = await _vendorsService.fetchVendors();
      _vendors
        ..clear()
        ..addAll(list);
    } catch (e) {
      if (e is http.ClientException) {
        _vendorsError = e.message;
      } else {
        _vendorsError = 'Unable to load vendors.';
      }
    } finally {
      _isLoadingVendors = false;
      notifyListeners();
    }
  }

  Future<void> refreshHistory({
    required Vendor vendor,
    String? status,
    DateTimeRange? dateRange,
  }) async {
    if (_isLoadingInitial) return;

    _historyVendor = vendor;
    _historyStatus = status;
    _historyDateRange = dateRange;
    _error = null;
    _visibleEntries.clear();
    _historyPage = 1;
    _historyHasMore = true;

    _isLoadingInitial = true;
    notifyListeners();

    try {
      final page = await _stockEntryService.fetchStockEntryHistoryPage(
        vendor: vendor,
        page: _historyPage,
        pageSize: 20,
        status: _historyStatus,
        startDate: _historyDateRange?.start,
        endDate: _historyDateRange?.end,
      );

      _visibleEntries
        ..clear()
        ..addAll(page.items);
      _historyHasMore = page.hasMore;
      _historyPage += 1;
    } catch (_) {
      _error = 'Unable to load history.';
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (_isLoadingMore || _isLoadingInitial) return;
    if (!hasMore) return;

    final vendor = _historyVendor;
    if (vendor == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _stockEntryService.fetchStockEntryHistoryPage(
        vendor: vendor,
        page: _historyPage,
        pageSize: 20,
        status: _historyStatus,
        startDate: _historyDateRange?.start,
        endDate: _historyDateRange?.end,
      );

      _visibleEntries.addAll(page.items);
      _historyHasMore = page.hasMore;
      _historyPage += 1;
    } catch (e) {
      _error = 'Unable to load more history.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
