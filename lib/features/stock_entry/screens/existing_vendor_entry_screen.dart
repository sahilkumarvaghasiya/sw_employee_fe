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
      appBar: AppBar(title: const Text('Existing Vendor Entry')),
      body: Column(
        children: [
          Padding(
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
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No vendors found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
