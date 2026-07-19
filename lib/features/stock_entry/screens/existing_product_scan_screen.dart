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
import '../widgets/stock_entry_ui.dart';

/// Find an existing catalog product (search or scan), review read-only details,
/// then restock with quantity + optional price overrides.
class ExistingProductScanScreen extends StatefulWidget {
  const ExistingProductScanScreen({super.key});

  static const String routeName = '/stock-entry/existing-product';

  static Route<List<StockEntryDraftItem>?> route() {
    return MaterialPageRoute<List<StockEntryDraftItem>?>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const ExistingProductScanScreen(),
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

  bool get _canAcceptBarcodeScans =>
      _scannerActive && !_handlingBarcode && _selected == null;

  @override
  void initState() {
    super.initState();
    unawaited(_startScanner());
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

  bool _matchesNameOrBrand(Product product, String query) {
    final needle = query.toLowerCase();
    return product.name.toLowerCase().contains(needle) ||
        product.companyName.toLowerCase().contains(needle);
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
      final page = await _productsService.fetchProductVariants(
        page: 1,
        pageSize: 30,
        filters: <String, String>{'search': trimmed},
      );
      if (!mounted || requestId != _searchRequestId) return;

      final filtered = page.items
          .where((product) => _matchesNameOrBrand(product, trimmed))
          .toList(growable: false);

      setState(() {
        _searchResults = filtered;
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
    Widget? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    );
  }

  Widget _readOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      readOnly: true,
      enableInteractiveSelection: true,
      decoration: _fieldDecoration(label: label, icon: icon),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = accent ?? colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.10),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(64)),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
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
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
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
                  )
                : null,
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
          const SizedBox(height: 12),
          StockEntryCompactScannerBar(
            scannerActive: _scannerActive,
            startingScanner: _startingScanner,
            onToggleScanner: () {
              if (_scannerActive) {
                unawaited(_stopScanner());
              } else {
                unawaited(_startScanner());
              }
            },
          ),
          if (_scannerActive) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: BarcodeScannerView(
                  controller: _scannerController,
                  profile: BarcodeScanProfile.stockEntry,
                  enabled: _canAcceptBarcodeScans,
                  hintText:
                      'Align the barcode inside the frame and hold steady.',
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
    String money(double v) => formatInr(v, decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Matched product',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Search again'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _sectionCard(
          icon: Icons.inventory_2_outlined,
          title: 'Product details',
          subtitle: 'Existing catalog values — view only',
          accent: AppColors.homeAccentTeal,
          children: [
            _readOnlyField(
              label: 'Barcode',
              value: product.barcode,
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 12),
            _readOnlyField(
              label: 'Brand',
              value: product.brandName.trim().isEmpty
                  ? 'No brand'
                  : product.brandName,
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 12),
            _readOnlyField(
              label: 'Item type',
              value: product.itemType2 != null &&
                      product.itemType2!.trim().isNotEmpty
                  ? '${product.itemType1} / ${product.itemType2}'
                  : product.itemType1,
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 12),
            _readOnlyField(
              label: 'Gender',
              value: product.gender.label,
              icon: Icons.wc_outlined,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _readOnlyField(
                    label: 'Size',
                    value: variant.size,
                    icon: Icons.straighten_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _readOnlyField(
                    label: 'Colour',
                    value: variant.colour,
                    icon: Icons.palette_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  theme: theme,
                  colorScheme: colorScheme,
                  icon: Icons.inventory_outlined,
                  label: 'In stock ${variant.inStock}',
                ),
                _infoChip(
                  theme: theme,
                  colorScheme: colorScheme,
                  icon: Icons.shopping_bag_outlined,
                  label: 'Purchase ${money(variant.purchasePrice)}',
                ),
                _infoChip(
                  theme: theme,
                  colorScheme: colorScheme,
                  icon: Icons.sell_outlined,
                  label: 'Sell ${money(variant.sellPrice)}',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          icon: Icons.add_box_outlined,
          title: 'Add stock',
          subtitle: 'Quantity required · prices optional',
          accent: AppColors.emerald,
          children: [
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _fieldDecoration(
                label: 'Quantity',
                icon: Icons.pin_outlined,
                hint: 'Pieces to add',
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease',
                      onPressed: () {
                        final current =
                            int.tryParse(_qtyController.text.trim()) ?? 1;
                        if (current <= 1) return;
                        setState(() {
                          _qtyController.text = '${current - 1}';
                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Increase',
                      onPressed: () {
                        final current =
                            int.tryParse(_qtyController.text.trim()) ?? 0;
                        setState(() {
                          _qtyController.text = '${current + 1}';
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _fieldDecoration(
                label: 'Purchase price (optional)',
                icon: Icons.currency_rupee_rounded,
                hint: money(variant.purchasePrice),
                helperText:
                    'Leave blank to keep ${money(variant.purchasePrice)}',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _fieldDecoration(
                label: 'Sell price (optional)',
                icon: Icons.sell_outlined,
                hint: money(variant.sellPrice),
                helperText: 'Leave blank to keep ${money(variant.sellPrice)}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoChip({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
        title: const Text(
          'Existing product',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (hasProduct)
            IconButton(
              tooltip: 'Clear',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            hasProduct
                ? 'Review details and add stock for this entry'
                : 'Search by product or brand, or scan a catalog barcode',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchAndScanner(theme, colorScheme),
          if (hasProduct) ...[
            const SizedBox(height: 18),
            _buildProductDetails(theme, colorScheme),
          ] else if (!_scannerActive &&
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
        ],
      ),
      bottomNavigationBar: hasProduct
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
