import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/vendors_provider.dart';
import '../widgets/vendors_ui.dart';
import 'vendor_payable_detail_screen.dart';
import 'vendor_report_screen.dart';

class VendorsHubScreen extends StatefulWidget {
  const VendorsHubScreen({super.key});

  static const String routeName = '/vendors';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => VendorsProvider(),
        child: const VendorsHubScreen(),
      ),
    );
  }

  @override
  State<VendorsHubScreen> createState() => _VendorsHubScreenState();
}

class _VendorsHubScreenState extends State<VendorsHubScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VendorsProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<VendorsProvider>();
    final summary = provider.summary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pay Vendor'),
        actions: [
          IconButton(
            tooltip: 'Download report',
            onPressed: () {
              Navigator.of(context).push(
                VendorReportScreen.route(provider: provider),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        color: AppColors.emerald,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: VendorsSearchBar(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: SliverToBoxAdapter(
                child: PayableTotalCard(
                  totalDisplay: summary.totalPendingDisplay,
                  pendingBills: summary.pendingBills,
                  overdue: summary.overdue,
                  dueThisWeek: summary.dueThisWeek,
                ),
              ),
            ),
            if (provider.vendors.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Vendors to pay',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (provider.isLoading && provider.vendors.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.vendors.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: VendorsEmptyState(
                  title: 'Couldn’t load vendors',
                  subtitle: 'Pull down to try again',
                  actionLabel: 'Retry',
                  onAction: provider.refresh,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (provider.vendors.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: VendorsEmptyState(
                  title: 'Nothing to pay',
                  subtitle: 'No open vendor balances right now',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList.separated(
                  itemCount: provider.vendors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final group = provider.vendors[index];
                    return VendorPayableTile(
                      group: group,
                      onTap: () async {
                        await Navigator.of(context).push(
                          VendorPayableDetailScreen.route(
                            group: group,
                            provider: provider,
                          ),
                        );
                        if (!mounted) return;
                        await provider.refresh();
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
