import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import 'new_vendor_entry_screen.dart';
import 'stock_entry_history_screen.dart';
import 'stock_scanning_screen.dart';
import '../widgets/stock_entry_ui.dart';

class StockEntryMainScreen extends StatefulWidget {
  const StockEntryMainScreen({super.key});

  static const String routeName = '/stock-entry';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const StockEntryMainScreen(),
    );
  }

  @override
  State<StockEntryMainScreen> createState() => _StockEntryMainScreenState();
}

class _StockEntryMainScreenState extends State<StockEntryMainScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<StockEntryProvider>();
      unawaited(provider.refreshVendors().then((_) {
        if (!mounted) return;
        _maybeLoadMore(provider);
      }));
    });
  }

  void _onScroll() {
    if (!mounted) return;
    _maybeLoadMore(context.read<StockEntryProvider>());
  }

  void _maybeLoadMore(StockEntryProvider provider) {
    if (!provider.vendorsHasMore) return;
    if (provider.isLoadingVendors || provider.isLoadingMoreVendors) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldLoad = position.pixels >= (position.maxScrollExtent - 240);
    if (!shouldLoad) return;

    unawaited(provider.loadMoreVendors().then((_) {
      if (!mounted) return;
      _maybeLoadMore(context.read<StockEntryProvider>());
    }));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<StockEntryProvider>();
    final vendors = provider.vendors;
    final showFooterLoader = provider.isLoadingMoreVendors;
    final query = provider.vendorsSearchQuery;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(NewVendorEntryScreen.route());
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New vendor'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshVendors,
        color: colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Stock Entry',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Entry history',
                  onPressed: () {
                    Navigator.of(context).push(StockEntryHistoryScreen.route());
                  },
                  icon: const Icon(Icons.history_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receive stock from a vendor',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const StockEntrySteps(currentStep: 1),
                    const SizedBox(height: 20),
                    Text(
                      'Select vendor',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a vendor to scan items and record payment',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    StockEntrySearchField(
                      controller: _searchController,
                      hint: 'Search by name or phone…',
                      onChanged: provider.setVendorsSearchQuery,
                      onClear: () {
                        _searchController.clear();
                        provider.setVendorsSearchQuery('');
                      },
                    ),
                  ],
                ),
              ),
            ),

            if (provider.isLoadingVendors && vendors.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.vendorsError != null && vendors.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StockEntryEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Could not load vendors',
                      message: provider.vendorsError!,
                      action: FilledButton(
                        onPressed: provider.refreshVendors,
                        child: const Text('Try again'),
                      ),
                    ),
                  ),
                ),
              )
            else if (vendors.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StockEntryEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No vendors found',
                      message: query.isEmpty
                          ? 'Add your first vendor to start receiving stock.'
                          : 'Try a different search or add a new vendor.',
                      action: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(NewVendorEntryScreen.route());
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add vendor'),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                sliver: SliverList.separated(
                  itemCount: vendors.length + (showFooterLoader ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= vendors.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      );
                    }

                    final vendor = vendors[index];
                    return StockEntryVendorTile(
                      name: vendor.name,
                      subtitle: _vendorSubtitle(vendor),
                      onTap: () {
                        Navigator.of(context).push(
                          StockScanningScreen.route(vendor: vendor),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _vendorSubtitle(Vendor vendor) {
    if (vendor.phone.trim().isNotEmpty) return vendor.phone.trim();
    if (vendor.address?.trim().isNotEmpty ?? false) {
      return vendor.address!.trim();
    }
    return 'Tap to add stock';
  }
}
