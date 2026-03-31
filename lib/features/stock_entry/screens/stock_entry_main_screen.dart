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

    final vendors = context.watch<StockEntryProvider>().vendors;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? vendors
        : vendors
              .where((v) {
                return v.name.toLowerCase().contains(query) ||
                    v.address.toLowerCase().contains(query);
              })
              .toList(growable: false);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add new vendor',
        onPressed: () {
          Navigator.of(context).push(NewVendorEntryScreen.route());
        },
        elevation: 2,
        hoverElevation: 8,
        focusElevation: 8,
        highlightElevation: 6,
        icon: const Icon(Icons.add),
        label: const Text('New vendor'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.06),
              colorScheme.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              backgroundColor: colorScheme.surface.withOpacity(0.92),
              title: const Text(
                'Stock Entry',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search vendor…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No vendors found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary.withAlpha(31),
                child: Icon(Icons.person_outline, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vendor.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
