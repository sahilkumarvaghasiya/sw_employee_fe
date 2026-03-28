import 'package:flutter/material.dart';

import 'existing_vendor_entry_screen.dart';
import 'new_vendor_entry_screen.dart';
import 'stock_entry_history_screen.dart';

class StockEntryMainScreen extends StatelessWidget {
  const StockEntryMainScreen({super.key});

  static const String routeName = '/stock-entry';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const StockEntryMainScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Entry')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Choose an option',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          _OptionCard(
            title: 'Stock Entry History',
            subtitle: 'View previous vendor stock entries',
            icon: Icons.history,
            onTap: () {
              Navigator.of(context).push(StockEntryHistoryScreen.route());
            },
          ),
          const SizedBox(height: 12),

          _OptionCard(
            title: 'New Vendor Entry',
            subtitle: 'Add a vendor and start entry',
            icon: Icons.person_add_alt_1_outlined,
            onTap: () {
              Navigator.of(context).push(NewVendorEntryScreen.route());
            },
          ),
          const SizedBox(height: 12),

          _OptionCard(
            title: 'Existing Vendor Entry',
            subtitle: 'Pick an existing vendor',
            icon: Icons.people_outline,
            onTap: () {
              Navigator.of(context).push(ExistingVendorEntryScreen.route());
            },
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(31),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
