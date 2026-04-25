import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'new_vendor_entry_screen.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import 'stock_scanning_screen.dart';

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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primaryContainer.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          tooltip: 'Add new vendor',
          onPressed: () {
            Navigator.of(context).push(NewVendorEntryScreen.route());
          },
          elevation: 2,
          icon: const Icon(Icons.add),
          label: const Text('New vendor'),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshVendors,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.92),
            title: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Stock Entry',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Select a vendor to begin stock entry',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(24),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search vendor…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                  ),
                ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 44,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        provider.vendorsError!,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: provider.refreshVendors,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: colorScheme.primary.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No vendors found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different name or add a new vendor.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final vendor = filtered[index];
                  return _VendorCard(
                    vendor: vendor,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).push(StockScanningScreen.route(vendor: vendor));
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
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor, required this.onTap});

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subtitle = vendor.phone.trim().isNotEmpty
        ? vendor.phone
        : (vendor.address?.trim().isNotEmpty ?? false)
        ? vendor.address!
        : '—';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PulsingArrowButton(onPressed: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingArrowButton extends StatefulWidget {
  const _PulsingArrowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PulsingArrowButton> createState() => _PulsingArrowButtonState();
}

class _PulsingArrowButtonState extends State<_PulsingArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.92,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 22,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
