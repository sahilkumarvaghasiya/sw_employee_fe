import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_size.dart';
import '../models/product_color.dart';
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

  final List<ProductSize> _sizes = [];
  final List<ProductColor> _colors = [];

  int _page = 1;
  final List<Product> _items = [];

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _requestGeneration = 0;

  String _searchQuery = '';
  Timer? _searchDebounce;

  final Set<ProductGender> _selectedGenders = {};
  late RangeValues _selectedPriceRange;
  DateTimeRange? _selectedDateRange;
  ProductSize? _selectedSize;
  ProductColor? _selectedColor;

  bool _isLoadingSizes = false;
  bool _isLoadingColors = false;

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

  List<ProductSize> get availableSizes => List.unmodifiable(_sizes);
  List<ProductColor> get availableColors => List.unmodifiable(_colors);
  String? get selectedSize => _selectedSize?.name;
  int? get selectedSizeId => _selectedSize?.id;
  String? get selectedColor => _selectedColor?.name;
  int? get selectedColorId => _selectedColor?.id;

  bool get hasActiveFilters {
      return _searchQuery.trim().isNotEmpty ||
        _selectedGenders.isNotEmpty ||
        _selectedDateRange != null ||
        _selectedSize != null ||
        _selectedColor != null ||
        _selectedPriceRange.start != _priceBounds.$1 ||
        _selectedPriceRange.end != _priceBounds.$2;
    }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void setSelectedSize(ProductSize? size) {
    if (_selectedSize?.id == size?.id) return;

    _selectedSize = size;
    _refetch();
  }

  void setSelectedColor(ProductColor? color) {
    if (_selectedColor?.id == color?.id) return;

    _selectedColor = color;
    _refetch();
  }

  Future<void> init() async {
    await Future.wait([_loadSizes(), _loadColors()]);
    await refresh();
  }

  Future<void> refresh() async {
    final requestGeneration = ++_requestGeneration;
    _isLoadingInitial = true;
    _error = null;
    _resetPaging(notify: false);
    notifyListeners();

    try {
      await _fetchNextPage(requestGeneration: requestGeneration, notify: false);
    } catch (_) {
      if (_isCurrentRequest(requestGeneration)) {
        _error = 'Failed to load products';
      }
    } finally {
      if (_isCurrentRequest(requestGeneration)) {
        _isLoadingInitial = false;
        notifyListeners();
      }
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
    _selectedColor = null;
    _refetch();
  }

  Future<void> _loadSizes() async {
    if (_isLoadingSizes) return;

    _isLoadingSizes = true;
    try {
      final sizes = await _service.fetchSizes();
      _sizes
        ..clear()
        ..addAll(sizes);

      if (_selectedSize != null) {
        final matches = _sizes.where((s) => s.id == _selectedSize!.id).toList();
        _selectedSize = matches.isNotEmpty ? matches.first : null;
      }
    } catch (_) {
      _sizes.clear();
    } finally {
      _isLoadingSizes = false;
      notifyListeners();
    }
  }

  Future<void> _loadColors() async {
    if (_isLoadingColors) return;

    _isLoadingColors = true;
    try {
      final colors = await _service.fetchColors();
      _colors
        ..clear()
        ..addAll(colors);

      if (_selectedColor != null) {
        final matches = _colors
            .where((s) => s.id == _selectedColor!.id)
            .toList();
        _selectedColor = matches.isNotEmpty ? matches.first : null;
      }
    } catch (_) {
      _colors.clear();
    } finally {
      _isLoadingColors = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoadingInitial || !_hasMore) return;

    _error = null;
    _isLoadingMore = true;
    notifyListeners();

    try {
      await _fetchNextPage(
        requestGeneration: _requestGeneration,
        notify: false,
      );
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
    _isLoadingMore = false;
    if (notify) notifyListeners();
  }

  void _refetch() {
    final requestGeneration = ++_requestGeneration;
    _error = null;
    _isLoadingInitial = true;
    _resetPaging(notify: false);
    notifyListeners();
    unawaited(() async {
      try {
        await _fetchNextPage(requestGeneration: requestGeneration);
      } catch (_) {
        if (_isCurrentRequest(requestGeneration)) {
          _error = 'Failed to load products';
        }
      } finally {
        if (_isCurrentRequest(requestGeneration)) {
          _isLoadingInitial = false;
          notifyListeners();
        }
      }
    }());
  }

  Map<String, String> _buildApiFilters() {
    final out = <String, String>{};

    final q = _searchQuery.trim();
    if (q.isNotEmpty) out['search'] = q;

    // Backend supports multiple genders as a comma-separated list.
    if (_selectedGenders.isNotEmpty) {
      out['gender'] = _selectedGenders.map((g) => g.name).join(',');
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

    if (_selectedSize != null) {
      out['size_id'] = _selectedSize!.id.toString();
    }
    if (_selectedColor != null) {
      out['color_id'] = _selectedColor!.id.toString();
    }

    return out;
  }

  static String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  bool _isCurrentRequest(int requestGeneration) {
    return requestGeneration == _requestGeneration;
  }

  Future<void> _fetchNextPage({
    required int requestGeneration,
    bool notify = true,
  }) async {
    if (!_hasMore) return;

    final page = await _service.fetchProductVariants(
      page: _page,
      pageSize: pageSize,
      filters: _buildApiFilters(),
    );

    if (!_isCurrentRequest(requestGeneration)) return;

    _items.addAll(page.items);
    _hasMore = page.hasMore;
    _page += 1;

    if (notify) notifyListeners();
  }
}
