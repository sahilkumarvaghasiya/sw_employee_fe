import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_bill_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/summary_metric_card.dart';
import '../../products/screens/products_screen.dart';
import '../../billing/screens/customer_form_screen.dart';
import '../../stock_alerts/providers/stock_alerts_provider.dart';
import '../../stock_alerts/screens/stock_alerts_screen.dart';
import '../../stock_entry/screens/stock_entry_main_screen.dart';
import '../../sales_history/screens/sales_history_screen.dart';

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
    final branchName = context.watch<AuthProvider>().branchName;

    final recentBills = <_RecentBill>[
      const _RecentBill(billNo: '10421', amount: 1299.00, method: 'UPI'),
      const _RecentBill(billNo: '10420', amount: 249.50, method: 'Cash'),
      const _RecentBill(billNo: '10419', amount: 799.00, method: 'Paytm'),
      const _RecentBill(billNo: '10418', amount: 159.00, method: 'UPI'),
      const _RecentBill(billNo: '10417', amount: 2199.00, method: 'Cash'),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(CustomerFormScreen.route());
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan & Bill'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: colorScheme.surfaceContainerLow.withAlpha(235),
            surfaceTintColor: colorScheme.surfaceTint,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RetailAgent',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                if (branchName.isNotEmpty)
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
              ],
            ),
            actions: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDark = themeProvider.isDark;
                  return IconButton(
                    tooltip: isDark
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                    onPressed: themeProvider.toggle,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  );
                },
              ),
              Consumer<StockAlertsProvider>(
                builder: (context, alertsProvider, _) {
                  alertsProvider.loadUnseenCountIfNeeded();

                  final count = alertsProvider.unseenCount;
                  final showBadge = count > 0;
                  final badgeText = count > 99 ? '99+' : '$count';

                  return IconButton(
                    tooltip: 'Stock alerts',
                    onPressed: () {
                      Navigator.of(context).push(StockAlertsScreen.route());
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined),
                        if (showBadge)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(
                                badgeText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
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
                  onTap: () {
                    Navigator.of(context).push(CustomerFormScreen.route());
                  },
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
                  onTap: () {
                    Navigator.of(context).push(SalesHistoryScreen.route());
                  },
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
    );
  }
}

class _EmployeeChip extends StatelessWidget {
  const _EmployeeChip({required this.name});

  final String name;

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final formKey = GlobalKey<FormState>();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final newFocus = FocusNode();
    final confirmFocus = FocusNode();

    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? submitError;

    Future<void> submit(StateSetter setState) async {
      FocusManager.instance.primaryFocus?.unfocus();
      if (!(formKey.currentState?.validate() ?? false)) return;

      setState(() {
        isSubmitting = true;
        submitError = null;
      });

      try {
        await context.read<AuthProvider>().changePassword(
          newPassword: newController.text,
        );
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        setState(() {
          submitError = 'Failed to change password';
          isSubmitting = false;
        });
      }
    }

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              title: Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Change password')),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set a new password for your account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: newController,
                        focusNode: newFocus,
                        obscureText: obscureNew,
                        textInputAction: TextInputAction.next,
                        enabled: !isSubmitting,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(confirmFocus);
                        },
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.password_rounded),
                          suffixIcon: IconButton(
                            tooltip: obscureNew
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: isSubmitting
                                ? null
                                : () =>
                                      setState(() => obscureNew = !obscureNew),
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'Enter a new password';
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmController,
                        focusNode: confirmFocus,
                        obscureText: obscureConfirm,
                        textInputAction: TextInputAction.done,
                        enabled: !isSubmitting,
                        onFieldSubmitted: (_) => submit(setState),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            tooltip: obscureConfirm
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: isSubmitting
                                ? null
                                : () => setState(
                                    () => obscureConfirm = !obscureConfirm,
                                  ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          final n = newController.text.trim();
                          if (v.isEmpty) return 'Confirm your new password';
                          if (v != n) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                submitError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : () => submit(setState),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    newController.dispose();
    confirmController.dispose();
    newFocus.dispose();
    confirmFocus.dispose();

    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  void _showAccountSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final initial = name.trim().isEmpty
            ? '?'
            : name.trim().characters.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      initial.toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 150));
                  if (!context.mounted) return;
                  await _showChangePasswordDialog(context);
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDark = themeProvider.isDark;
                  return SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    secondary: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    title: Text(isDark ? 'White mode' : 'Dark mode'),
                    value: isDark,
                    onChanged: (value) {
                      themeProvider.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  );
                },
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text(
                  'Log out',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await context.read<AuthProvider>().logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showAccountSheet(context),
      child: Container(
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
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
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
