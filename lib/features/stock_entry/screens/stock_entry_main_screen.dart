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
    final colorScheme = theme.colorScheme;

    return Scaffold(
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      title: 'Choose an option',
                      subtitle:
                          'Create a new entry for a vendor, or review past entries.',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 12),
                    _OptionCard(
                      title: 'New Vendor Entry',
                      subtitle: 'Add a vendor and start entry',
                      icon: Icons.person_add_alt_1_outlined,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(NewVendorEntryScreen.route());
                      },
                    ),
                    const SizedBox(height: 12),
                    _OptionCard(
                      title: 'Existing Vendor Entry',
                      subtitle: 'Pick an existing vendor',
                      icon: Icons.people_outline,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(ExistingVendorEntryScreen.route());
                      },
                    ),
                    const SizedBox(height: 12),
                    _OptionCard(
                      title: 'Stock Entry History',
                      subtitle: 'View previous vendor stock entries',
                      icon: Icons.history,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(StockEntryHistoryScreen.route());
                      },
                    ),
                    const Spacer(),
                    _InfoFooterCard(
                      text:
                          'Tip: Use “New Vendor Entry” for first-time vendors, and “Existing Vendor Entry” for repeat suppliers.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(28),
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
                      fontWeight: FontWeight.w900,
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
          ],
        ),
      ),
    );
  }
}

class _InfoFooterCard extends StatelessWidget {
  const _InfoFooterCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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
