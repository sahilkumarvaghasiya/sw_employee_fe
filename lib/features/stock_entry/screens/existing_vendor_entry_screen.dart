import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import '../widgets/stock_entry_ui.dart';
import 'stock_scanning_screen.dart';

class ExistingVendorEntryScreen extends StatefulWidget {
  const ExistingVendorEntryScreen({super.key});

  static const String routeName = '/stock-entry/existing-vendor';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const ExistingVendorEntryScreen(),
    );
  }

  @override
  State<ExistingVendorEntryScreen> createState() =>
      _ExistingVendorEntryScreenState();
}

class _ExistingVendorEntryScreenState extends State<ExistingVendorEntryScreen> {
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

    final provider = context.watch<StockEntryProvider>();
    final vendors = provider.vendors;
    final showFooterLoader = provider.isLoadingMoreVendors;
    final query = provider.vendorsSearchQuery;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Select vendor')),
      body: RefreshIndicator(
        onRefresh: provider.refreshVendors,
        color: colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StockEntrySteps(currentStep: 1),
                    const SizedBox(height: 16),
                    StockEntrySearchField(
                      controller: _searchController,
                      hint: 'Search vendor…',
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
                          ? 'No vendors yet.'
                          : 'Try a different search term.',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
