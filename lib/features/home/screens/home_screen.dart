import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final employeeName = context.watch<AuthProvider>().employeeName;
    final branchName = context.watch<AuthProvider>().branchName;
    final firstName = employeeName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _openAndRefresh(CustomerFormScreen.route());
        },
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan & Bill'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.indigo,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeroHeader(
                greeting: _greeting(),
                employeeName: firstName.isNotEmpty ? firstName : 'there',
                branchName: branchName,
                isDark: isDark,
                onAlertsTap: () async {
                  await _openAndRefresh(StockAlertsScreen.route());
                },
                onThemeToggle: () => context.read<ThemeProvider>().toggle(),
                isDarkMode: context.watch<ThemeProvider>().isDark,
                alertCount: context.watch<StockAlertsProvider>().unseenCount,
                employeeChip: _EmployeeChip(name: employeeName),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Quick actions',
                  subtitle: 'Everything you need in one tap',
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate.fixed([
                  QuickActionCard(
                    title: 'Start Billing',
                    subtitle: 'Scan & checkout',
                    icon: Icons.qr_code_scanner_rounded,
                    isPrimary: true,
                    onTap: () async {
                      await _openAndRefresh(CustomerFormScreen.route());
                    },
                  ),
                  QuickActionCard(
                    title: 'Stock Entry',
                    subtitle: 'Receive inventory',
                    icon: Icons.inventory_2_outlined,
                    accentColor: AppColors.homeAccentAmber,
                    onTap: () async {
                      await _openAndRefresh(StockEntryMainScreen.route());
                    },
                  ),
                  QuickActionCard(
                    title: 'Products',
                    subtitle: 'Browse catalog',
                    icon: Icons.grid_view_rounded,
                    accentColor: AppColors.homeAccentViolet,
                    onTap: () async {
                      await _openAndRefresh(ProductsScreen.route());
                    },
                  ),
                  QuickActionCard(
                    title: 'Sales History',
                    subtitle: 'Past bills',
                    icon: Icons.receipt_long_outlined,
                    accentColor: AppColors.homeAccentSky,
                    onTap: () async {
                      await _openAndRefresh(SalesHistoryScreen.route());
                    },
                  ),
                ]),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Today at a glance',
                  subtitle: 'Live stats from your store',
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                            icon: Icons.payments_rounded,
                            accentColor: AppColors.homeAccentTeal,
                          ),
                          SummaryMetricCard(
                            label: 'Bills Generated',
                            value: summary?.billsGenerated.toString() ?? '0',
                            icon: Icons.receipt_long_rounded,
                            accentColor: AppColors.indigo,
                          ),
                          SummaryMetricCard(
                            label: 'Items Sold',
                            value: summary?.itemsSold.toString() ?? '0',
                            icon: Icons.shopping_bag_outlined,
                            accentColor: AppColors.homeAccentAmber,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recent activity',
                  subtitle: 'Latest bills from today',
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              sliver: Consumer<HomeDashboardProvider>(
                builder: (context, dashboardProvider, _) {
                  final recent =
                      dashboardProvider.data?.recentActivity ?? const [];

                  if (dashboardProvider.isLoading && recent.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
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
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.slate200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No recent bills yet',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start billing to see activity here',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      childCount: recent.length,
                      (context, index) {
                        final bill = recent[index];
                        const billAccents = [
                          AppColors.homeAccentTeal,
                          AppColors.indigo,
                          AppColors.homeAccentSky,
                          AppColors.homeAccentAmber,
                        ];

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == recent.length - 1 ? 0 : 10,
                          ),
                          child: RecentBillTile(
                            billNo: bill.billNumber,
                            amount: bill.amountDisplay,
                            method: bill.paymentMethodLabel,
                            accentColor: billAccents[index % billAccents.length],
                            onTap: null,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroHeader extends StatelessWidget {
  const _HomeHeroHeader({
    required this.greeting,
    required this.employeeName,
    required this.branchName,
    required this.isDark,
    required this.onAlertsTap,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.alertCount,
    required this.employeeChip,
  });

  final String greeting;
  final String employeeName;
  final String branchName;
  final bool isDark;
  final VoidCallback onAlertsTap;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final int alertCount;
  final Widget employeeChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors =
        isDark ? AppColors.heroGradientDark : AppColors.heroGradientLight;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (branchName.isNotEmpty)
                          Text(
                            branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
                    onPressed: onThemeToggle,
                    icon: Icon(
                      isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Stock alerts',
                        onPressed: onAlertsTap,
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (alertCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            child: Text(
                              alertCount > 99 ? '99+' : '$alertCount',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  employeeChip,
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$greeting,',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employeeName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ready to serve customers today',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
                        : () => Navigator.of(dialogContext).pop(),
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
                      : () => Navigator.of(dialogContext).pop(),
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
                    radius: 22,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      initial.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
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
                leading: Icon(Icons.lock_outline, color: colorScheme.primary),
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
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showAccountSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              child: Text(
                initial.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}
