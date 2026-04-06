import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/products_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/products_filter_section.dart';
import '../widgets/products_search_bar.dart';
import 'product_detail_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final FocusNode _sizeFocusNode = FocusNode();

  final MenuController _sizeMenuController = MenuController();
  Timer? _sizeDebounce;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;

      // Trigger pagination when close to the bottom.
      if (position.pixels >= position.maxScrollExtent - 320) {
        context.read<ProductsProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _sizeController.dispose();
    _sizeFocusNode.dispose();
    _sizeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _openFiltersSheet() async {
    final productsProvider = context.read<ProductsProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              top: 12,
            ),
            child: ChangeNotifierProvider<ProductsProvider>.value(
              value: productsProvider,
              child: ProductsFilterSection(
                onCloseRequested: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<ProductsProvider>();

    if (!_sizeFocusNode.hasFocus) {
      final desiredText = provider.selectedSize ?? '';
      if (_sizeController.text != desiredText) {
        _sizeController.value = TextEditingValue(
          text: desiredText,
          selection: TextSelection.collapsed(offset: desiredText.length),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
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

                      void applyTypedSize(String value) {
                        _sizeDebounce?.cancel();
                        _sizeDebounce = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            if (!mounted) return;
                            provider.setSelectedSize(value);
                          },
                        );
                      }

                      final sizeMenu = MenuAnchor(
                        controller: _sizeMenuController,
                        style: MenuStyle(
                          maximumSize: WidgetStatePropertyAll(
                            Size(constraints.maxWidth, 320),
                          ),
                        ),
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () {
                              _sizeController.clear();
                              provider.setSelectedSize(null);
                              _sizeMenuController.close();
                            },
                            child: const Text('All sizes'),
                          ),
                          ...provider.availableSizes.map(
                            (s) => MenuItemButton(
                              onPressed: () {
                                _sizeController.text = s;
                                _sizeController.selection =
                                    TextSelection.collapsed(offset: s.length);
                                provider.setSelectedSize(s);
                                _sizeMenuController.close();
                              },
                              child: Text(s),
                            ),
                          ),
                        ],
                        builder: (context, controller, child) {
                          return TextField(
                            controller: _sizeController,
                            focusNode: _sizeFocusNode,
                            textInputAction: TextInputAction.done,
                            onChanged: applyTypedSize,
                            onSubmitted: provider.setSelectedSize,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHigh,
                              prefixIcon: const Icon(Icons.straighten_outlined),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 42,
                                minHeight: 42,
                              ),
                              hintText: 'Size',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Show sizes',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      if (isNarrow) {
                        return Row(
                          children: [
                            Expanded(child: search),
                            const SizedBox(width: 10),
                            SizedBox(width: 140, child: sizeMenu),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 10),
                          SizedBox(width: 190, child: sizeMenu),
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
            else if (provider.error != null)
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
                    return ProductCard(
                      product: product,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProductDetailScreen(product: product),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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

    return const SizedBox(height: 8);
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
