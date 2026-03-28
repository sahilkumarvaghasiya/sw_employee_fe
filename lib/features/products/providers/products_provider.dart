import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider({this.pageSize = 20}) {
    _allProducts = _generateDummyProducts(count: 240);
    _availableBrands = _allProducts.map((p) => p.companyName).toSet().toList()
      ..sort();

    _priceBounds = _computePriceBounds(_allProducts);
    _selectedPriceRange = RangeValues(_priceBounds.$1, _priceBounds.$2);
  }

  final int pageSize;

  late final List<String> _availableBrands;
  late final (double, double) _priceBounds;

  late List<Product> _allProducts;
  List<Product> _filteredProducts = const [];
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
  String? _selectedBrand;

  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  List<Product> get items => List.unmodifiable(_items);

  String get searchQuery => _searchQuery;
  Set<ProductGender> get selectedGenders => Set.unmodifiable(_selectedGenders);
  RangeValues get selectedPriceRange => _selectedPriceRange;
  DateTimeRange? get selectedDateRange => _selectedDateRange;
  String? get selectedBrand => _selectedBrand;
  List<String> get availableBrands => List.unmodifiable(_availableBrands);
  (double, double) get priceBounds => _priceBounds;

  bool get hasActiveFilters {
    return _selectedGenders.isNotEmpty ||
        _selectedBrand != null ||
        _selectedDateRange != null ||
        _selectedPriceRange.start != _priceBounds.$1 ||
        _selectedPriceRange.end != _priceBounds.$2;
  }

  Future<void> init() async {
    _isLoadingInitial = true;
    _error = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _applyFiltersAndResetPaging();
      await _loadNextPage();
    } catch (e) {
      _error = 'Failed to load products';
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _error = null;
    _applyFiltersAndResetPaging();
    notifyListeners();
    await _loadNextPage();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _error = null;
      _applyFiltersAndResetPaging();
      notifyListeners();
      unawaited(_loadNextPage());
    });

    notifyListeners();
  }

  void applyFilters({
    required Set<ProductGender> genders,
    required RangeValues priceRange,
    required DateTimeRange? dateRange,
    required String? brand,
  }) {
    _selectedGenders
      ..clear()
      ..addAll(genders);
    _selectedPriceRange = priceRange;
    _selectedDateRange = dateRange;
    _selectedBrand = (brand == null || brand.trim().isEmpty) ? null : brand;

    _error = null;
    _applyFiltersAndResetPaging();
    notifyListeners();
    unawaited(_loadNextPage());
  }

  void resetFilters() {
    _selectedGenders.clear();
    _selectedBrand = null;
    _selectedDateRange = null;
    _selectedPriceRange = RangeValues(_priceBounds.$1, _priceBounds.$2);

    _error = null;
    _applyFiltersAndResetPaging();
    notifyListeners();
    unawaited(_loadNextPage());
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoadingInitial || !_hasMore) return;
    _error = null;
    _isLoadingMore = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await _loadNextPage();
    } catch (e) {
      _error = 'Failed to load more products';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _applyFiltersAndResetPaging() {
    _items.clear();
    _hasMore = true;
    _filteredProducts = _applyFilters(_allProducts);
  }

  List<Product> _applyFilters(List<Product> products) {
    final q = _searchQuery.trim().toLowerCase();

    return products
        .where((p) {
          if (q.isNotEmpty) {
            final matchesName = p.name.toLowerCase().contains(q);
            final matchesBarcode = p.barcode.toLowerCase().contains(q);
            if (!matchesName && !matchesBarcode) return false;
          }

          if (_selectedGenders.isNotEmpty &&
              !_selectedGenders.contains(p.gender)) {
            return false;
          }

          if (_selectedBrand != null && p.companyName != _selectedBrand) {
            return false;
          }

          if (p.price < _selectedPriceRange.start ||
              p.price > _selectedPriceRange.end) {
            return false;
          }

          if (_selectedDateRange != null) {
            final start = _selectedDateRange!.start;
            final end = _selectedDateRange!.end;
            if (p.createdAt.isBefore(
              DateTime(start.year, start.month, start.day),
            )) {
              return false;
            }
            if (p.createdAt.isAfter(
              DateTime(end.year, end.month, end.day, 23, 59, 59),
            )) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;

    final startIndex = _items.length;
    final endIndex = min(startIndex + pageSize, _filteredProducts.length);

    if (startIndex >= _filteredProducts.length) {
      _hasMore = false;
      return;
    }

    _items.addAll(_filteredProducts.sublist(startIndex, endIndex));
    _hasMore = endIndex < _filteredProducts.length;
  }

  static (double, double) _computePriceBounds(List<Product> products) {
    if (products.isEmpty) return (0, 0);

    double minPrice = products.first.price;
    double maxPrice = products.first.price;

    for (final p in products) {
      if (p.price < minPrice) minPrice = p.price;
      if (p.price > maxPrice) maxPrice = p.price;
    }

    // Round to nice bounds.
    final minRounded = (minPrice / 50).floor() * 50.0;
    final maxRounded = (maxPrice / 50).ceil() * 50.0;
    return (minRounded, maxRounded);
  }

  static List<Product> _generateDummyProducts({required int count}) {
    final random = Random(7);

    const brands = [
      'Nova Apparel',
      'UrbanCo',
      'BluePeak',
      'Astra',
      'DashWear',
      'MintMode',
    ];

    const sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

    const productBases = [
      'Cotton T-Shirt',
      'Slim Fit Jeans',
      'Sports Shoes',
      'Casual Shirt',
      'Hoodie',
      'Track Pants',
      'Kurti',
      'Sneakers',
      'Formal Trousers',
      'Jacket',
      'Socks Pack',
      'Cap',
      'Belt',
      'Wallet',
      'Handbag',
    ];

    final now = DateTime.now();

    return List<Product>.generate(count, (i) {
      final brand = brands[random.nextInt(brands.length)];
      final size = sizes[random.nextInt(sizes.length)];
      final base = productBases[random.nextInt(productBases.length)];

      final genderRoll = random.nextDouble();
      final gender = genderRoll < 0.42
          ? ProductGender.men
          : genderRoll < 0.84
          ? ProductGender.women
          : ProductGender.unisex;

      final price = 99 + random.nextInt(4901) + (random.nextInt(99) / 100.0);
      final qty = random.nextInt(160);

      final createdAt = now.subtract(Duration(days: random.nextInt(45)));
      final id = 'P${(i + 1).toString().padLeft(5, '0')}';
      final barcode = '890${(100000000 + i).toString()}';

      return Product(
        id: id,
        name: '$base ${(i % 6) + 1}',
        barcode: barcode,
        quantityInStock: qty,
        size: size,
        companyName: brand,
        price: double.parse(price.toStringAsFixed(2)),
        gender: gender,
        createdAt: createdAt,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
