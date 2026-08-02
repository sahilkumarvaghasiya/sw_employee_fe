import 'package:flutter/material.dart';
import '../models/sales_bill.dart';
import '../services/sales_history_service.dart';

class SalesHistoryProvider extends ChangeNotifier {
  SalesHistoryProvider({SalesHistoryService? service})
    : _service = service ?? SalesHistoryService();

  final SalesHistoryService _service;

  List<SalesBill> _bills = const <SalesBill>[];
  final Map<String, SalesBill> _detailsCache = <String, SalesBill>{};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalCount = 0;
  String? _error;
  DateTimeRange? _dateRange;
  double? _maxTotal;
  String _searchQuery = '';
  int _requestGeneration = 0;

  List<SalesBill> get bills => List.unmodifiable(_bills);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  String? get error => _error;
  DateTimeRange? get dateRange => _dateRange;
  double? get maxTotal => _maxTotal;
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
      final page = await _service.fetchSalesHistoryPage(
        search: _searchQuery,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        maxTotal: _maxTotal,
        page: 1,
      );
      if (requestGeneration != _requestGeneration) return;
      _bills = page.bills;
      _hasMore = page.hasNext;
      _totalCount = page.count;
      _page = 2;
      _detailsCache.clear();
    } catch (_) {
      if (requestGeneration == _requestGeneration) {
        _error = 'Failed to load sales history';
        _bills = const [];
        _hasMore = false;
        _totalCount = 0;
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;

    final requestGeneration = _requestGeneration;
    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _service.fetchSalesHistoryPage(
        search: _searchQuery,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        maxTotal: _maxTotal,
        page: _page,
      );
      if (requestGeneration != _requestGeneration) return;
      _bills = [..._bills, ...page.bills];
      _hasMore = page.hasNext;
      _totalCount = page.count;
      _page += 1;
    } catch (_) {
      if (requestGeneration == _requestGeneration) {
        _error = 'Failed to load more bills';
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> applyFilters({
    DateTimeRange? dateRange,
    double? maxTotal,
  }) async {
    await applyQueryFilters(dateRange: dateRange, maxTotal: maxTotal);
  }

  Future<void> updateSearchQuery(String value) async {
    await applyQueryFilters(searchQuery: value);
  }

  Future<void> applyQueryFilters({
    DateTimeRange? dateRange,
    double? maxTotal,
    String? searchQuery,
  }) async {
    _dateRange = dateRange;
    _maxTotal = maxTotal;
    if (searchQuery != null) {
      _searchQuery = searchQuery.trim();
    }
    await refresh();
  }

  Future<SalesBill> fetchBillDetails(String billId) async {
    final normalizedId = billId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Sales bill id is required');
    }

    final cached = _detailsCache[normalizedId];
    if (cached != null) return cached;

    final details = await _service.fetchSalesHistoryDetails(normalizedId);
    // Prefer the requested UUID when detail payload omits/overwrites id.
    final resolved = details.id.trim().isEmpty || details.id == details.billNo
        ? details.copyWith(id: normalizedId)
        : details;
    _detailsCache[normalizedId] = resolved;
    return resolved;
  }

  void updateWhatsAppStatus(String billId, WhatsAppBillStatus status) {
    final normalizedId = billId.trim();
    if (normalizedId.isEmpty) return;

    _bills = [
      for (final bill in _bills)
        if (bill.id == normalizedId)
          bill.copyWith(whatsappStatus: status)
        else
          bill,
    ];

    final cached = _detailsCache[normalizedId];
    if (cached != null) {
      _detailsCache[normalizedId] = cached.copyWith(whatsappStatus: status);
    }

    notifyListeners();
  }
}
