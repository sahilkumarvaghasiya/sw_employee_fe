import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/product.dart';
import '../models/product_size.dart';
import '../models/product_color.dart';
import '../providers/products_provider.dart';
import '../services/products_service.dart';
import 'product_detail_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/products_filter_section.dart';
import '../widgets/products_search_bar.dart';
import '../widgets/products_ui.dart';
import '../widgets/searchable_dropdown.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => ProductsProvider()..init(),
        child: const ProductsScreen(),
      ),
    );
  }

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ProductsService _productsService = ProductsService();

  bool _postFramePaginationScheduled = false;
  String? _loadingProductId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // If the first page doesn't fill the viewport, auto-fetch until it does
    // (or until there's no more data).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeLoadMore(context.read<ProductsProvider>());
    });
  }

  void _onScroll() {
    if (!mounted) return;
    _maybeLoadMore(context.read<ProductsProvider>());
  }

  void _maybeLoadMore(ProductsProvider provider) {
    if (!provider.hasMore) return;
    if (provider.isLoadingInitial || provider.isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldLoad = position.pixels >= (position.maxScrollExtent - 240);
    if (!shouldLoad) return;

    unawaited(provider.loadMore());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sizeController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _openFiltersSheet() async {
    final productsProvider = context.read<ProductsProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              16 + media.viewInsets.bottom,
            ),
            child: ChangeNotifierProvider<ProductsProvider>.value(
              value: productsProvider,
              child: SingleChildScrollView(
                child: ProductsFilterSection(
                  onCloseRequested: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _advancedFilterCount(ProductsProvider provider) {
    var count = 0;
    if (provider.selectedGenders.isNotEmpty) count++;
    if (provider.selectedDateRange != null) count++;
    final bounds = provider.priceBounds;
    final range = provider.selectedPriceRange;
    if (range.start > bounds.$1 || range.end < bounds.$2) count++;
    return count;
  }

  Future<void> _openProductDetails(Product product) async {
    if (_loadingProductId != null) return;

    setState(() => _loadingProductId = product.id);
    try {
      final details = await _productsService.fetchProductDetails(
        productId: product.id,
      );

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(product: details),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to load product details.')),
        );
    } finally {
      if (mounted) {
        setState(() => _loadingProductId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<ProductsProvider>();
    final advancedFilterCount = _advancedFilterCount(provider);
    final hasQuickFilters = provider.selectedSize != null ||
        provider.selectedColor != null ||
        provider.searchQuery.trim().isNotEmpty;
    final headerHeight = hasQuickFilters ? 140.0 : 96.0;

    // If content doesn't fill the viewport, keep auto-fetching pages until it
    // does (or until there's no more data). This runs after layout.
    if (!_postFramePaginationScheduled &&
        provider.items.isNotEmpty &&
        provider.hasMore &&
        !provider.isLoadingInitial &&
        !provider.isLoadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent <= 0) {
      _postFramePaginationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFramePaginationScheduled = false;
        if (!mounted) return;
        _maybeLoadMore(context.read<ProductsProvider>());
      });
    }

    final desiredText = provider.selectedSize ?? '';
    if (_sizeController.text != desiredText) {
      _sizeController.value = TextEditingValue(
        text: desiredText,
        selection: TextSelection.collapsed(offset: desiredText.length),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (provider.hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _sizeController.clear();
                provider.resetFilters();
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear all'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        color: AppColors.emerald,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                height: headerHeight,
                child: ColoredBox(
                  color: isDark ? AppColors.slate950 : AppColors.slate50,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProductsSearchBar(
                          controller: _searchController,
                          onChanged: provider.setSearchQuery,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SearchableDropdown<ProductSize>(
                                    placeholder: 'Size',
                                    width: constraints.maxWidth,
                                    height: 40,
                                    prefixIcon: Icons.straighten_rounded,
                                    selectedLabel: provider.selectedSize,
                                    options: provider.availableSizes
                                        .map(
                                          (s) =>
                                              SearchableDropdownOption<
                                                  ProductSize>(
                                            label: s.name,
                                            value: s,
                                          ),
                                        )
                                        .toList(growable: false),
                                    filterHintText: 'Type size',
                                    onClear: () {
                                      _sizeController.clear();
                                      provider.setSelectedSize(null);
                                    },
                                    clearLabel: 'All sizes',
                                    onSelected: (opt) {
                                      _sizeController.text = opt.label;
                                      _sizeController.selection =
                                          TextSelection.collapsed(
                                        offset: opt.label.length,
                                      );
                                      provider.setSelectedSize(opt.value);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SearchableDropdown<ProductColor>(
                                    placeholder: 'Color',
                                    width: constraints.maxWidth,
                                    height: 40,
                                    prefixIcon: Icons.palette_outlined,
                                    selectedLabel: provider.selectedColor,
                                    options: provider.availableColors
                                        .map(
                                          (c) =>
                                              SearchableDropdownOption<
                                                  ProductColor>(
                                            label: c.name,
                                            value: c,
                                          ),
                                        )
                                        .toList(growable: false),
                                    filterHintText: 'Type colour',
                                    onClear: () =>
                                        provider.setSelectedColor(null),
                                    clearLabel: 'All colours',
                                    onSelected: (opt) {
                                      provider.setSelectedColor(opt.value);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ProductsCompactFilterButton(
                              activeCount: advancedFilterCount,
                              onTap: _openFiltersSheet,
                            ),
                          ],
                        ),
                        if (hasQuickFilters) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (provider.searchQuery.trim().isNotEmpty)
                                  ProductsActiveFilterChip(
                                    label: 'Search: ${provider.searchQuery.trim()}',
                                    onRemove: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                    },
                                  ),
                                if (provider.selectedSize != null) ...[
                                  if (provider.searchQuery.trim().isNotEmpty)
                                    const SizedBox(width: 6),
                                  ProductsActiveFilterChip(
                                    label: 'Size: ${provider.selectedSize}',
                                    onRemove: () {
                                      _sizeController.clear();
                                      provider.setSelectedSize(null);
                                    },
                                  ),
                                ],
                                if (provider.selectedColor != null) ...[
                                  const SizedBox(width: 6),
                                  ProductsActiveFilterChip(
                                    label: 'Color: ${provider.selectedColor}',
                                    onRemove: () =>
                                        provider.setSelectedColor(null),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (provider.isLoadingInitial)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ProductsEmptyState(
                  title: 'Could not load products',
                  subtitle: provider.error,
                  actionLabel: 'Try again',
                  onAction: provider.refresh,
                  icon: Icons.cloud_off_outlined,
                ),
              )
            else if (provider.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ProductsEmptyState(
                  title: 'No products found',
                  subtitle: provider.hasActiveFilters
                      ? 'Try adjusting your search or filters'
                      : 'Products will appear here once added',
                  actionLabel:
                      provider.hasActiveFilters ? 'Clear filters' : null,
                  onAction: provider.hasActiveFilters
                      ? () {
                          _searchController.clear();
                          _sizeController.clear();
                          provider.resetFilters();
                        }
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final product = provider.items[index];
                    final isLoadingThis = _loadingProductId == product.id;
                    return ProductCard(
                      product: product,
                      isLoading: isLoadingThis,
                      onTap: () => _openProductDetails(product),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: provider.items.length,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _PaginationFooter(
                  isLoadingMore: provider.isLoadingMore,
                  hasMore: provider.hasMore,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoadingMore, required this.hasMore});

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!hasMore && !isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'All products loaded',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Infinite scroll: next page loads automatically as the user reaches bottom.
    return const SizedBox.shrink();
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: height,
      child: Material(
        color: isDark ? AppColors.slate950 : AppColors.slate50,
        elevation: overlapsContent ? 0.5 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: overlapsContent
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.slate200,
                    ),
                  )
                : null,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
