import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
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
      appBar: AppBar(title: const Text('Existing Vendor Entry')),
      body: RefreshIndicator(
        onRefresh: provider.refreshVendors,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search vendor...',
                    prefixIcon: Icon(Icons.search),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    child: Text(
                      'No vendors found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final vendor = filtered[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filtered.length - 1 ? 0 : 12,
                      ),
                      child: _VendorCard(
                        vendor: vendor,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(StockScanningScreen.route(vendor: vendor));
                        },
                      ),
                    );
                  }, childCount: filtered.length),
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

    final phone = vendor.phone.trim().isEmpty ? '-' : vendor.phone.trim();
    final address = vendor.address?.trim() ?? '';

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
    final colorScheme = Theme.of(context).colorScheme;

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
