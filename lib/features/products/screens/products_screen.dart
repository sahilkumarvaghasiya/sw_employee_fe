import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/products_service.dart';
import 'product_detail_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/products_filter_section.dart';
import '../widgets/products_search_bar.dart';
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
              16,
              6,
              16,
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
    final colorScheme = theme.colorScheme;

    final provider = context.watch<ProductsProvider>();

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
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Reset filters',
            onPressed: provider.hasActiveFilters
                ? () {
                    _searchController.clear();
                    _sizeController.clear();
                    provider.setSearchQuery('');
                    provider.resetFilters();
                  }
                : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFiltersSheet,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                height: 96,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;

                      final search = ProductsSearchBar(
                        controller: _searchController,
                        onChanged: provider.setSearchQuery,
                      );

                      final sizeOptions = provider.availableSizes
                          .map(
                            (s) => SearchableDropdownOption<String>(
                              label: s,
                              value: s,
                            ),
                          )
                          .toList(growable: false);

                      final sizeMenu = SearchableDropdown<String>(
                        placeholder: 'Size',
                        width: isNarrow ? 140 : 190,
                        height: 48,
                        selectedLabel: provider.selectedSize,
                        options: sizeOptions,
                        filterHintText: 'Type size',
                        onClear: () {
                          _sizeController.clear();
                          provider.setSelectedSize(null);
                        },
                        clearLabel: 'All sizes',
                        onSelected: (opt) {
                          _sizeController.text = opt.label;
                          _sizeController.selection = TextSelection.collapsed(
                            offset: opt.label.length,
                          );
                          provider.setSelectedSize(opt.value);
                        },
                      );

                      if (isNarrow) {
                        return Row(
                          children: [
                            Expanded(child: search),
                            const SizedBox(width: 10),
                            sizeMenu,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 10),
                          sizeMenu,
                        ],
                      );
                    },
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.error!,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: provider.refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (provider.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No products found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final product = provider.items[index];
                    final isLoadingThis = _loadingProductId == product.id;
                    return ProductCard(
                      product: product,
                      onTap: isLoadingThis
                          ? () {}
                          : () => _openProductDetails(product),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: provider.items.length,
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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

    if (!hasMore) {
      return Center(
        child: Text(
          'You’re all caught up',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Material(
        color: colorScheme.surface,
        elevation: overlapsContent ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
