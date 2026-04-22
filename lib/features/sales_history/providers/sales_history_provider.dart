import 'package:flutter/material.dart';
import '../models/sales_bill.dart';
import '../services/sales_history_service.dart';

class SalesHistoryProvider extends ChangeNotifier {
  SalesHistoryProvider({SalesHistoryService? service})
    : _service = service ?? SalesHistoryService();

  final SalesHistoryService _service;

  List<SalesBill> _bills = const <SalesBill>[];
  bool _isLoading = false;
  String? _error;
  DateTimeRange? _dateRange;
  double? _maxTotal;
  String _searchQuery = '';

  List<SalesBill> get bills => List.unmodifiable(_bills);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTimeRange? get dateRange => _dateRange;
  double? get maxTotal => _maxTotal;
  String get searchQuery => _searchQuery;

  Future<void> refresh() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bills = await _service.fetchSalesHistoryList(
        search: _searchQuery,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        maxTotal: _maxTotal,
      );
    } catch (_) {
      _error = 'Failed to load sales history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({
    DateTimeRange? dateRange,
    double? maxTotal,
  }) async {
    await applyQueryFilters(
      dateRange: dateRange,
      maxTotal: maxTotal,
    );
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
}
