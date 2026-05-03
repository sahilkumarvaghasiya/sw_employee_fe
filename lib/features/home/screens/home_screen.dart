import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_dashboard_provider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Future<void> _refreshDashboard() {
    return Future.wait([
      context.read<HomeDashboardProvider>().refresh(),
      context.read<AuthProvider>().refreshUserInfo(),
      context.read<StockAlertsProvider>().refreshForHome(),
    ]);
  }

  Future<void> _openAndRefresh(Route<dynamic> route) async {
    await Navigator.of(context).push(route);
    if (!mounted) return;
    await _refreshDashboard();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshDashboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refreshDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final employeeName = context.watch<AuthProvider>().employeeName;
    final branchName = context.watch<AuthProvider>().branchName;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _openAndRefresh(CustomerFormScreen.route());
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan & Bill'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  final count = alertsProvider.unseenCount;
                  final showBadge = count > 0;
                  final badgeText = count > 99 ? '99+' : '$count';

                  return IconButton(
                    tooltip: 'Stock alerts',
                    onPressed: () async {
                      await _openAndRefresh(StockAlertsScreen.route());
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
                  onTap: () async {
                    await _openAndRefresh(CustomerFormScreen.route());
                  },
                ),
                QuickActionCard(
                  title: 'Stock Entry',
                  icon: Icons.inventory_2_outlined,
                  onTap: () async {
                    await _openAndRefresh(StockEntryMainScreen.route());
                  },
                ),
                QuickActionCard(
                  title: 'View Products',
                  icon: Icons.list_alt_outlined,
                  onTap: () async {
                    await _openAndRefresh(ProductsScreen.route());
                  },
                ),
                QuickActionCard(
                  title: 'Sales History',
                  icon: Icons.receipt_long_outlined,
                  onTap: () async {
                    await _openAndRefresh(SalesHistoryScreen.route());
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
              child: Consumer<HomeDashboardProvider>(
                builder: (context, dashboardProvider, _) {
                  final data = dashboardProvider.data;
                  final summary = data?.todaySummary;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 520;

                      final cards = [
                        SummaryMetricCard(
                          label: 'Total Sales Today',
                          value: summary == null
                              ? '₹0.00'
                              : '₹${summary.totalSalesDisplay}',
                          icon: Icons.payments_outlined,
                        ),
                        SummaryMetricCard(
                          label: 'Bills Generated',
                          value:
                              summary?.billsGenerated.toString() ?? '0',
                          icon: Icons.receipt_long_outlined,
                        ),
                        SummaryMetricCard(
                          label: 'Items Sold',
                          value: summary?.itemsSold.toString() ?? '0',
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ];

                      final cardLayout = isWide
                          ? Row(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[1]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[2]),
                              ],
                            )
                          : Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1],
                                const SizedBox(height: 12),
                                cards[2],
                              ],
                            );

                      if (dashboardProvider.error != null && data == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cardLayout,
                            const SizedBox(height: 10),
                            Text(
                              dashboardProvider.error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      }

                      return cardLayout;
                    },
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
            sliver: Consumer<HomeDashboardProvider>(
              builder: (context, dashboardProvider, _) {
                final recent = dashboardProvider.data?.recentActivity ?? const [];

                if (dashboardProvider.isLoading && recent.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (dashboardProvider.error != null && recent.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        dashboardProvider.error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                if (recent.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No recent bills yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    childCount: recent.length,
                    (context, index) {
                      final bill = recent[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == recent.length - 1 ? 0 : 12,
                        ),
                        child: RecentBillTile(
                          billNo: bill.billNumber,
                          amount: bill.amountDisplay,
                          method: bill.paymentMethodLabel,
                          onTap: null,
                        ),
                      );
                    },
                  ),
                );
              },
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
        final message = await context.read<AuthProvider>().changePassword(
          newPassword: newController.text,
          confirmPassword: confirmController.text,
        );
        if (context.mounted) Navigator.of(context).pop(message);
      } catch (e) {
        setState(() {
          submitError = e.toString().replaceFirst('Exception: ', '');
          isSubmitting = false;
        });
      }
    }

    final successMessage = await showDialog<String>(
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
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
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
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
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

    if (successMessage != null &&
        successMessage.isNotEmpty &&
        context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
      await context.read<AuthProvider>().logout();
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
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  if (!context.mounted) return;
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
