import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/products_service.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider({this.pageSize = 10, ProductsService? service})
    : _service = service ?? ProductsService() {
    _priceBounds = (0, 5000);
    _selectedPriceRange = RangeValues(_priceBounds.$1, _priceBounds.$2);
  }

  final int pageSize;
  final ProductsService _service;

  late final (double, double) _priceBounds;

  static final List<String> _staticSizes = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'XXXL',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
  ];

  int _page = 1;
  final List<Product> _items = [];

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  Timer? _searchDebounce;

  final Set<ProductGender> _selectedGenders = {};
  late RangeValues _selectedPriceRange;
  DateTimeRange? _selectedDateRange;
  String? _selectedSize;

  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  List<Product> get items => List.unmodifiable(_items);

  String get searchQuery => _searchQuery;
  Set<ProductGender> get selectedGenders => Set.unmodifiable(_selectedGenders);
  RangeValues get selectedPriceRange => _selectedPriceRange;
  DateTimeRange? get selectedDateRange => _selectedDateRange;
  (double, double) get priceBounds => _priceBounds;

  List<String> get availableSizes => List.unmodifiable(_staticSizes);
  String? get selectedSize => _selectedSize;

  bool get hasActiveFilters {
    return _selectedGenders.isNotEmpty ||
        _selectedDateRange != null ||
        _selectedSize != null ||
        _selectedPriceRange.start != _priceBounds.$1 ||
        _selectedPriceRange.end != _priceBounds.$2;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void setSelectedSize(String? size) {
    final normalized = (size == null || size.trim().isEmpty)
        ? null
        : size.trim().toUpperCase();
    if (_selectedSize == normalized) return;

    _selectedSize = normalized;
    _refetch();
  }

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoadingInitial) return;

    _isLoadingInitial = true;
    _error = null;
    _resetPaging(notify: false);
    notifyListeners();

    try {
      await _fetchNextPage(notify: false);
    } catch (_) {
      _error = 'Failed to load products';
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    _searchQuery = value;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _refetch();
    });

    notifyListeners();
  }

  void applyFilters({
    required Set<ProductGender> genders,
    required RangeValues priceRange,
    required DateTimeRange? dateRange,
  }) {
    _selectedGenders
      ..clear()
      ..addAll(genders);
    _selectedPriceRange = priceRange;
    _selectedDateRange = dateRange;

    _refetch();
  }

  void resetFilters() {
    _selectedGenders.clear();
    _selectedDateRange = null;
    _selectedPriceRange = RangeValues(_priceBounds.$1, _priceBounds.$2);
    _selectedSize = null;
    _refetch();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoadingInitial || !_hasMore) return;

    _error = null;
    _isLoadingMore = true;
    notifyListeners();

    try {
      await _fetchNextPage(notify: false);
    } catch (_) {
      _error = 'Failed to load more products';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _resetPaging({bool notify = true}) {
    _page = 1;
    _items.clear();
    _hasMore = true;
    if (notify) notifyListeners();
  }

  void _refetch() {
    _error = null;
    _resetPaging(notify: false);
    notifyListeners();
    unawaited(_fetchNextPage());
  }

  Map<String, String> _buildApiFilters() {
    final out = <String, String>{};

    final q = _searchQuery.trim();
    if (q.isNotEmpty) out['search'] = q;

    // Backend supports a single gender filter value.
    if (_selectedGenders.length == 1) {
      out['gender'] = _selectedGenders.first.name;
    }

    if (_selectedPriceRange.start != _priceBounds.$1) {
      out['min_price'] = _selectedPriceRange.start.toStringAsFixed(0);
    }
    if (_selectedPriceRange.end != _priceBounds.$2) {
      out['max_price'] = _selectedPriceRange.end.toStringAsFixed(0);
    }

    // Only send dates when the user has selected a range.
    if (_selectedDateRange != null) {
      out['start_date'] = _ddMMyyyy(_selectedDateRange!.start);
      out['end_date'] = _ddMMyyyy(_selectedDateRange!.end);
    }

    // NOTE: Backend expects size_id, but size filter stays static/client-side for now.
    return out;
  }

  static String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  Future<void> _fetchNextPage({bool notify = true}) async {
    if (!_hasMore) return;

    final page = await _service.fetchProductVariants(
      page: _page,
      pageSize: pageSize,
      filters: _buildApiFilters(),
    );

    final normalizedSize = _selectedSize;
    final List<Product> filtered = normalizedSize == null
        ? page.items
        : page.items
              .where(
                (p) => p.size.trim().toUpperCase().contains(normalizedSize),
              )
              .toList(growable: false);

    _items.addAll(filtered);
    _hasMore = page.hasMore;
    _page += 1;

    if (notify) notifyListeners();
  }
}
