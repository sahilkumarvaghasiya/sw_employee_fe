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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StockEntryProvider>().refreshVendors();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<StockEntryProvider>();
    final vendors = provider.vendors;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? vendors
        : vendors
              .where((v) {
                return v.name.toLowerCase().contains(query) ||
                    (v.address ?? '').toLowerCase().contains(query) ||
                    v.phone.toLowerCase().contains(query);
              })
              .toList(growable: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Select vendor')),
      body: RefreshIndicator(
        onRefresh: provider.refreshVendors,
        color: colorScheme.primary,
        child: CustomScrollView(
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
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
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
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StockEntryEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No vendors found',
                      message: 'Try a different search term.',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final vendor = filtered[index];
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
