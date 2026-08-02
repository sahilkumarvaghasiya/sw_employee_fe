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
  bool _isLoadingMoreVendors = false;
  bool _vendorsHasMore = true;
  int _vendorsPage = 1;
  String _vendorsSearchQuery = '';
  int _vendorsRequestGeneration = 0;
  Timer? _vendorsSearchDebounce;
  String? _vendorsError;

  Vendor? _historyVendor;

  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  bool get isLoadingVendors => _isLoadingVendors;
  bool get isLoadingMoreVendors => _isLoadingMoreVendors;
  bool get vendorsHasMore => _vendorsHasMore;
  String? get vendorsError => _vendorsError;
  String get vendorsSearchQuery => _vendorsSearchQuery;

  Vendor? get historyVendor => _historyVendor;

  List<Vendor> get vendors => List.unmodifiable(_vendors);
  List<StockEntry> get entries => List.unmodifiable(_visibleEntries);

  bool get hasMore => _historyHasMore;

  void reset() {
    _vendorsSearchDebounce?.cancel();
    _vendors.clear();
    _visibleEntries.clear();
    _historyPage = 1;
    _historyHasMore = true;
    _historyStatus = null;
    _historyDateRange = null;
    _historyVendor = null;
    _isLoadingInitial = false;
    _isLoadingMore = false;
    _error = null;
    _isLoadingVendors = false;
    _isLoadingMoreVendors = false;
    _vendorsHasMore = true;
    _vendorsPage = 1;
    _vendorsSearchQuery = '';
    _vendorsRequestGeneration = 0;
    _vendorsError = null;
    notifyListeners();
  }

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
    // If the current history view is for this vendor, keep it in sync.
    if (_historyVendor?.id == entry.vendor.id) {
      addStockEntry(entry);
    }
  }

  void setVendorsSearchQuery(String value) {
    _vendorsSearchQuery = value.trim();
    notifyListeners();
    _vendorsSearchDebounce?.cancel();
    _vendorsSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refreshVendors());
    });
  }

  Future<void> refreshVendors() async {
    final requestGeneration = ++_vendorsRequestGeneration;
    _isLoadingVendors = true;
    _isLoadingMoreVendors = false;
    _vendorsError = null;
    _vendorsPage = 1;
    _vendorsHasMore = true;
    notifyListeners();

    try {
      final page = await _vendorsService.fetchVendorsPage(
        search: _vendorsSearchQuery,
        page: 1,
      );

      if (requestGeneration != _vendorsRequestGeneration) return;

      _vendors
        ..clear()
        ..addAll(page.vendors);
      _vendorsHasMore = page.hasNext;
      _vendorsPage = 2;
    } catch (e) {
      if (requestGeneration != _vendorsRequestGeneration) return;
      if (e is http.ClientException) {
        _vendorsError = e.message;
      } else {
        _vendorsError = 'Unable to load vendors.';
      }
      _vendors.clear();
      _vendorsHasMore = false;
    } finally {
      if (requestGeneration == _vendorsRequestGeneration) {
        _isLoadingVendors = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreVendors() async {
    if (_isLoadingVendors || _isLoadingMoreVendors || !_vendorsHasMore) return;

    final requestGeneration = _vendorsRequestGeneration;
    _isLoadingMoreVendors = true;
    notifyListeners();

    try {
      final page = await _vendorsService.fetchVendorsPage(
        search: _vendorsSearchQuery,
        page: _vendorsPage,
      );

      if (requestGeneration != _vendorsRequestGeneration) return;

      _vendors.addAll(page.vendors);
      _vendorsHasMore = page.hasNext;
      _vendorsPage += 1;
    } catch (_) {
      if (requestGeneration != _vendorsRequestGeneration) return;
      // Keep existing list; user can scroll again to retry.
    } finally {
      if (requestGeneration == _vendorsRequestGeneration) {
        _isLoadingMoreVendors = false;
        notifyListeners();
      }
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

  @override
  void dispose() {
    _vendorsSearchDebounce?.cancel();
    super.dispose();
  }
}
