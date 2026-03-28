import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_bill_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/summary_metric_card.dart';
import '../../products/screens/products_screen.dart';
import '../../stock_entry/screens/stock_entry_main_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final employeeName = context.watch<AuthProvider>().employeeName;

    final recentBills = <_RecentBill>[
      const _RecentBill(billNo: '10421', amount: 1299.00, method: 'UPI'),
      const _RecentBill(billNo: '10420', amount: 249.50, method: 'Cash'),
      const _RecentBill(billNo: '10419', amount: 799.00, method: 'Paytm'),
      const _RecentBill(billNo: '10418', amount: 159.00, method: 'UPI'),
      const _RecentBill(billNo: '10417', amount: 2199.00, method: 'Cash'),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSnack(context, 'Scan & Bill (coming soon)'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan & Bill'),
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
              floating: false,
              elevation: 0,
              scrolledUnderElevation: 1,
              backgroundColor: colorScheme.surface.withOpacity(0.92),
              surfaceTintColor: colorScheme.surfaceTint,
              title: const Text(
                'RetailAgent',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => _showSnack(context, 'Notifications'),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _EmployeeChip(name: employeeName),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Quick actions',
                  action: Text(
                    'Tap to start',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                delegate: SliverChildListDelegate.fixed([
                  QuickActionCard(
                    title: 'Start Billing',
                    icon: Icons.qr_code_scanner,
                    isPrimary: true,
                    onTap: () =>
                        _showSnack(context, 'Start Billing (coming soon)'),
                  ),
                  QuickActionCard(
                    title: 'Stock Entry',
                    icon: Icons.inventory_2_outlined,
                    onTap: () {
                      Navigator.of(context).push(StockEntryMainScreen.route());
                    },
                  ),
                  QuickActionCard(
                    title: 'View Products',
                    icon: Icons.list_alt_outlined,
                    onTap: () {
                      Navigator.of(context).push(ProductsScreen.route());
                    },
                  ),
                  QuickActionCard(
                    title: 'Sales History',
                    icon: Icons.receipt_long_outlined,
                    onTap: () =>
                        _showSnack(context, 'Sales History (coming soon)'),
                  ),
                ]),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: const SliverToBoxAdapter(
                child: SectionHeader(title: 'Today summary'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 520;

                    final cards = const [
                      SummaryMetricCard(
                        label: 'Total Sales Today',
                        value: '₹18,450',
                        icon: Icons.payments_outlined,
                      ),
                      SummaryMetricCard(
                        label: 'Bills Generated',
                        value: '42',
                        icon: Icons.receipt_long_outlined,
                      ),
                      SummaryMetricCard(
                        label: 'Items Sold',
                        value: '186',
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[2]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                        const SizedBox(height: 12),
                        cards[2],
                      ],
                    );
                  },
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: const SliverToBoxAdapter(
                child: SectionHeader(title: 'Recent activity'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: recentBills.length,
                  (context, index) {
                    final bill = recentBills[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == recentBills.length - 1 ? 0 : 12,
                      ),
                      child: RecentBillTile(
                        billNo: bill.billNo,
                        amount: bill.amount,
                        method: bill.method,
                        onTap: () => _showSnack(
                          context,
                          'Bill #${bill.billNo} (coming soon)',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _EmployeeChip extends StatelessWidget {
  const _EmployeeChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primary.withOpacity(0.12),
            child: Text(
              initial.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBill {
  const _RecentBill({
    required this.billNo,
    required this.amount,
    required this.method,
  });

  final String billNo;
  final double amount;
  final String method;
}
