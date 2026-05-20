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
  String? _error;
  DateTimeRange? _dateRange;
  double? _maxTotal;
  String _searchQuery = '';
  int _requestGeneration = 0;

  List<SalesBill> get bills => List.unmodifiable(_bills);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTimeRange? get dateRange => _dateRange;
  double? get maxTotal => _maxTotal;
  String get searchQuery => _searchQuery;

  Future<void> refresh() async {
    final requestGeneration = ++_requestGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bills = await _service.fetchSalesHistoryList(
        search: _searchQuery,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        maxTotal: _maxTotal,
      );
      if (requestGeneration != _requestGeneration) return;
      _bills = bills;
      _detailsCache.clear();
    } catch (_) {
      if (requestGeneration == _requestGeneration) {
        _error = 'Failed to load sales history';
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isLoading = false;
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
    _detailsCache[normalizedId] = details;
    return details;
  }
}
