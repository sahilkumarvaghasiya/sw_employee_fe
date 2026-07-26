import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/barcode_scan_validator.dart';
import '../../../core/utils/inr_format.dart';
import '../../../core/widgets/barcode_scanner_view.dart';
import '../../billing/services/billing_service.dart';
import '../../products/models/product.dart';
import '../../products/services/products_service.dart';
import '../models/existing_stock_product.dart';
import '../models/stock_entry_draft_item.dart';
import '../models/vendor.dart';
import '../services/stock_entry_service.dart';
import '../widgets/stock_entry_ui.dart';

/// Find an existing catalog product (search or scan), review read-only details,
/// then restock with quantity + optional price overrides.
class ExistingProductScanScreen extends StatefulWidget {
  const ExistingProductScanScreen({
    super.key,
    required this.vendor,
    this.initialDraft,
  });

  /// Current stock-entry vendor — search is scoped to this vendor's products.
  final Vendor vendor;

  /// When set, opens in edit mode with this restock draft prefilled.
  final StockEntryDraftItem? initialDraft;

  static const String routeName = '/stock-entry/existing-product';

  static Route<List<StockEntryDraftItem>?> route({
    required Vendor vendor,
    StockEntryDraftItem? initialDraft,
  }) {
    return MaterialPageRoute<List<StockEntryDraftItem>?>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => ExistingProductScanScreen(
        vendor: vendor,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  State<ExistingProductScanScreen> createState() =>
      _ExistingProductScanScreenState();
}

class _ExistingProductScanScreenState extends State<ExistingProductScanScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _purchaseController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();

  final MobileScannerController _scannerController =
      createBarcodeScannerController(
    autoStart: false,
    profile: BarcodeScanProfile.stockEntry,
  );

  final ProductsService _productsService = ProductsService();
  final BillingService _billingService = BillingService();
  final StockEntryService _stockEntryService = StockEntryService();

  Timer? _searchDebounce;
  int _searchRequestId = 0;
  List<Product> _searchResults = const [];
  bool _isSearching = false;
  String? _searchError;
  final Set<String> _loadingDetailIds = <String>{};

  bool _scannerActive = false;
  bool _startingScanner = false;
  bool _handlingBarcode = false;

  ExistingStockProduct? _selected;
  int _selectedVariantIndex = 0;
  bool _isPrefilling = false;

  bool get _isEditing => widget.initialDraft != null;

  bool get _canAcceptBarcodeScans =>
      _scannerActive && !_handlingBarcode && _selected == null;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      unawaited(_prefillFromDraft(draft));
    } else {
      unawaited(_startScanner());
    }
  }

  Future<void> _prefillFromDraft(StockEntryDraftItem draft) async {
    setState(() => _isPrefilling = true);

    try {
      final normalized = normalizeStockBarcodeValue(draft.barcode);
      if (normalized.isNotEmpty) {
        final matches =
            await _billingService.fetchProductsByBarcode(normalized);
        if (!mounted) return;

        if (matches.isNotEmpty) {
          final details = await _productsService.fetchProductDetails(
            productId: matches.first.id,
          );
          if (!mounted) return;

          _applySelection(ExistingStockProduct.fromProduct(details));
          _applyDraftFieldValues(draft);
          return;
        }
      }
    } catch (_) {
      // Fall through to local reconstruction.
    }

    if (!mounted) return;
    _applySelectionFromDraft(draft);
  }

  void _applyDraftFieldValues(StockEntryDraftItem draft) {
    final product = _selected;
    if (product != null && draft.variantId != null) {
      final idx = product.variants.indexWhere(
        (v) => v.variantId == draft.variantId,
      );
      if (idx >= 0) {
        _selectedVariantIndex = idx;
      }
    }

    setState(() {
      _qtyController.text = draft.quantity.toString();
      _purchaseController.text = draft.costPriceOverride != null
          ? draft.costPriceOverride!.toStringAsFixed(2)
          : '';
      _sellController.text = draft.sellingPriceOverride != null
          ? draft.sellingPriceOverride!.toStringAsFixed(2)
          : '';
      _isPrefilling = false;
    });
  }

  void _applySelectionFromDraft(StockEntryDraftItem draft) {
    final variantId = draft.variantId;
    if (variantId == null) {
      setState(() => _isPrefilling = false);
      _showSnack('Cannot edit this item — missing variant.');
      unawaited(_startScanner());
      return;
    }

    unawaited(_stopScanner());

    setState(() {
      _selected = ExistingStockProduct(
        barcode: draft.barcode,
        barcodeUrl: draft.barcodeUrl,
        brandId: draft.brandId,
        brandName: draft.brandName,
        gender: draft.gender,
        isPair: draft.isPair,
        itemTypeId: draft.itemTypeId,
        itemType1: draft.itemType1,
        itemType2: draft.itemType2,
        variants: [
          ExistingStockProductVariant(
            variantId: variantId,
            sizeId: draft.sizeId,
            size: draft.size,
            colourId: draft.colourId,
            colour: draft.colour,
            purchasePrice: draft.costPrice,
            sellPrice: draft.sellingPrice,
          ),
        ],
      );
      _selectedVariantIndex = 0;
      _searchController.clear();
      _searchResults = const [];
      _searchError = null;
      _qtyController.text = draft.quantity.toString();
      _purchaseController.text = draft.costPriceOverride != null
          ? draft.costPriceOverride!.toStringAsFixed(2)
          : '';
      _sellController.text = draft.sellingPriceOverride != null
          ? draft.sellingPriceOverride!.toStringAsFixed(2)
          : '';
      _isPrefilling = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    unawaited(_scannerController.dispose());
    _searchController.dispose();
    _qtyController.dispose();
    _purchaseController.dispose();
    _sellController.dispose();
    super.dispose();
  }

  Future<void> _startScanner() async {
    if (_startingScanner || _scannerActive) return;
    setState(() => _startingScanner = true);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await _scannerController.start();
      if (!mounted) return;
      setState(() {
        _scannerActive = true;
        _startingScanner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerActive = false;
        _startingScanner = false;
      });
      _showSnack(
        'Camera could not start. Use the search bar or try again.',
      );
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() {
      _scannerActive = false;
      _startingScanner = false;
    });
  }

  Future<void> _runSearch(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = const [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final page = await _stockEntryService.fetchVendorProducts(
        vendorId: widget.vendor.id,
        search: trimmed,
        page: 1,
        pageSize: 30,
      );
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _searchResults = page.items;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = const [];
        _isSearching = false;
        _searchError = 'Could not load products. Try again.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(value));
    });
    setState(() {});
  }

  Future<void> _loadDetailsAndSelect(String productId) async {
    final id = productId.trim();
    if (id.isEmpty || _loadingDetailIds.contains(id)) return;

    setState(() => _loadingDetailIds.add(id));
    try {
      await _stopScanner();
      if (!mounted) return;

      final details = await _productsService.fetchProductDetails(productId: id);
      if (!mounted) return;
      _applySelection(ExistingStockProduct.fromProduct(details));
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to load product details.');
      if (_selected == null) {
        unawaited(_startScanner());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDetailIds.remove(id));
      }
    }
  }

  Future<void> _handleBarcode(String raw) async {
    if (!_canAcceptBarcodeScans) return;

    final normalized = normalizeStockBarcodeValue(raw);
    if (normalized.isEmpty) return;

    _handlingBarcode = true;
    try {
      await _stopScanner();
      if (!mounted) return;

      final matches = await _billingService.fetchProductsByBarcode(normalized);
      if (!mounted) return;

      if (matches.isEmpty) {
        _showSnack('No product found for barcode $normalized');
        await _startScanner();
        return;
      }

      // Prefer full details so restock gets barcode, stock qty, and prices.
      await _loadDetailsAndSelect(matches.first.id);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Barcode lookup failed. Try search instead.');
      await _startScanner();
    } finally {
      _handlingBarcode = false;
    }
  }

  void _applySelection(ExistingStockProduct product) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_stopScanner());

    setState(() {
      _selected = product;
      _selectedVariantIndex = 0;
      _searchController.clear();
      _searchResults = const [];
      _searchError = null;
      _qtyController.text = '1';
      _purchaseController.clear();
      _sellController.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _selectedVariantIndex = 0;
      _qtyController.text = '1';
      _purchaseController.clear();
      _sellController.clear();
    });
    unawaited(_startScanner());
  }

  ExistingStockProductVariant? get _activeVariant {
    final product = _selected;
    if (product == null || product.variants.isEmpty) return null;
    final i = _selectedVariantIndex.clamp(0, product.variants.length - 1);
    return product.variants[i];
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final product = _selected;
    final variant = _activeVariant;
    if (product == null || variant == null) {
      _showSnack('Scan or search for a product first.');
      return;
    }

    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      _showSnack('Quantity must be at least 1.');
      return;
    }

    final purchaseRaw = _purchaseController.text.trim().replaceAll(',', '');
    final sellRaw = _sellController.text.trim().replaceAll(',', '');

    double? purchaseOverride;
    double? sellOverride;

    if (purchaseRaw.isNotEmpty) {
      purchaseOverride = double.tryParse(purchaseRaw);
      if (purchaseOverride == null || purchaseOverride < 0) {
        _showSnack('Enter a valid purchase price.');
        return;
      }
    }

    if (sellRaw.isNotEmpty) {
      sellOverride = double.tryParse(sellRaw);
      if (sellOverride == null || sellOverride < 0) {
        _showSnack('Enter a valid sell price.');
        return;
      }
    }

    final draft = StockEntryDraftItem(
      barcode: product.barcode,
      barcodeUrl: product.barcodeUrl,
      brandId: product.brandId,
      brandName: product.brandName,
      sizeId: variant.sizeId,
      size: variant.size,
      colourId: variant.colourId,
      colour: variant.colour,
      gender: product.gender,
      isPair: product.isPair,
      itemTypeId: product.itemTypeId,
      itemType1: product.itemType1,
      itemType2: product.itemType2,
      quantity: qty,
      costPrice: purchaseOverride ?? variant.purchasePrice,
      sellingPrice: sellOverride ?? variant.sellPrice,
      isExisting: true,
      variantId: variant.variantId,
      costPriceOverride: purchaseOverride,
      sellingPriceOverride: sellOverride,
    );

    Navigator.of(context).pop(<StockEntryDraftItem>[draft]);
  }

  InputDecoration _simpleFieldDecoration({
    required String label,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? colorScheme.outlineVariant
              : const Color(0xFFD7E2DF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.emerald, width: 1.4),
      ),
    );
  }

  Widget _buildSearchScanActions(ColorScheme colorScheme) {
    final hasQuery = _searchController.text.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasQuery)
          IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              _searchController.clear();
              _searchDebounce?.cancel();
              setState(() {
                _searchResults = const [];
                _isSearching = false;
                _searchError = null;
              });
            },
          ),
        if (_startingScanner)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: _scannerActive ? 'Stop camera' : 'Scan barcode',
            icon: Icon(
              _scannerActive
                  ? Icons.videocam_off_rounded
                  : Icons.qr_code_scanner_rounded,
              color: _scannerActive
                  ? AppColors.homeAccentTeal
                  : colorScheme.primary,
            ),
            onPressed: () {
              if (_scannerActive) {
                unawaited(_stopScanner());
              } else {
                unawaited(_startScanner());
              }
            },
          ),
      ],
    );
  }

  Widget _buildSearchAndScanner(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _searchDebounce?.cancel();
            unawaited(_runSearch(value));
          },
          decoration: InputDecoration(
            hintText: 'Search product or brand…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _buildSearchScanActions(colorScheme),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            filled: true,
            fillColor: isDark ? colorScheme.surface : Colors.white,
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _searchError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (_searchController.text.isNotEmpty &&
            _searchResults.isEmpty &&
            _selected == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No matching products',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_searchResults.isNotEmpty && _selected == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.28,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  final isLoading = _loadingDetailIds.contains(product.id);
                  return _ExistingSearchResultTile(
                    product: product,
                    isLoading: isLoading,
                    onTap: isLoading
                        ? null
                        : () => unawaited(_loadDetailsAndSelect(product.id)),
                  );
                },
              ),
            ),
          ),
        if (_selected == null) ...[
          if (_scannerActive) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: BarcodeScannerView(
                  controller: _scannerController,
                  profile: BarcodeScanProfile.stockEntry,
                  enabled: _canAcceptBarcodeScans,
                  hintText:
                      'Align barcode bars in the green frame — move closer if small',
                  onBarcodeConfirmed: (value) {
                    unawaited(_handleBarcode(value));
                  },
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Camera unavailable',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => unawaited(_stopScanner()),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildProductDetails(ThemeData theme, ColorScheme colorScheme) {
    final product = _selected!;
    final variant = _activeVariant!;
    final isDark = theme.brightness == Brightness.dark;
    String money(double v) => formatInr(v, decimalDigits: 0);

    final itemType = product.itemType2 != null &&
            product.itemType2!.trim().isNotEmpty
        ? '${product.itemType1} / ${product.itemType2}'
        : product.itemType1;
    final brand = product.brandName.trim().isEmpty
        ? 'No brand'
        : product.brandName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Selected product',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // Soft read-only summary — clearly not editable.
        Opacity(
          opacity: 0.72,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
                  : const Color(0xFFECF4F3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                    : const Color(0xFFB7D4CF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catalog details · view only',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark
                        ? colorScheme.onSurfaceVariant
                        : const Color(0xFF5F7A76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _mutedRow('Barcode', product.barcode, theme, isDark),
                _mutedRow('Brand', brand, theme, isDark),
                _mutedRow('Item', itemType, theme, isDark),
                _mutedRow(
                  'Variant',
                  '${variant.size} · ${variant.colour} · ${product.gender.label}',
                  theme,
                  isDark,
                ),
                _mutedRow(
                  'In stock',
                  '${variant.inStock} pcs',
                  theme,
                  isDark,
                ),
                _mutedRow(
                  'Purchase',
                  money(variant.purchasePrice),
                  theme,
                  isDark,
                ),
                _mutedRow(
                  'Sell',
                  money(variant.sellPrice),
                  theme,
                  isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          'Add stock',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _qtyController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _simpleFieldDecoration(
            label: 'Quantity',
            hint: 'Pieces to add',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purchaseController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: _simpleFieldDecoration(
            label: 'Purchase price (optional)',
            hint: money(variant.purchasePrice),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sellController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: _simpleFieldDecoration(
            label: 'Sell price (optional)',
            hint: money(variant.sellPrice),
          ),
        ),
      ],
    );
  }

  Widget _mutedRow(String label, String value, ThemeData theme, bool isDark) {
    final labelColor =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF6B8581);
    final valueColor =
        isDark ? theme.colorScheme.onSurface.withValues(alpha: 0.78) : const Color(0xFF3D5551);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasProduct = _selected != null && _activeVariant != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit existing product' : 'Existing product',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (hasProduct)
            IconButton(
              tooltip: 'Change product',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _isPrefilling
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                if (!hasProduct) ...[
                  Text(
                    'Search by product or brand, or scan a catalog barcode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSearchAndScanner(theme, colorScheme),
                  if (!_scannerActive &&
                      _searchResults.isEmpty &&
                      !_isSearching) ...[
                    const SizedBox(height: 28),
                    const StockEntryEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Find an existing product',
                      message:
                          'Search by product name or brand, or scan a barcode, then add quantity.',
                    ),
                  ],
                ] else
                  _buildProductDetails(theme, colorScheme),
              ],
            ),
      bottomNavigationBar: hasProduct && !_isPrefilling
          ? StockEntryBottomBar(
              label: 'Update',
              icon: Icons.check_rounded,
              onPressed: _submit,
              subtitle: '${_selected!.displayName} · ${_activeVariant!.label}',
            )
          : null,
    );
  }
}

class _ExistingSearchResultTile extends StatelessWidget {
  const _ExistingSearchResultTile({
    required this.product,
    required this.onTap,
    this.isLoading = false,
  });

  final Product product;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final meta = [
      if (product.companyName.trim().isNotEmpty) product.companyName.trim(),
      if (product.size.trim().isNotEmpty && product.size != '—')
        'Size ${product.size}',
      if (product.color.trim().isNotEmpty && product.color != '—')
        product.color,
    ].join(' · ');

    return Material(
      color: isDark ? colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.slate200,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.homeAccentTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.homeAccentTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.trim().isEmpty
                          ? 'Product'
                          : product.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatInr(product.price, decimalDigits: 0),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldDark,
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
