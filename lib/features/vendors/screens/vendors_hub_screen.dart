import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
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

  Future<void> _pickDateRange() async {
    final provider = context.read<VendorsProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.dateRange,
    );
    if (!mounted) return;
    await provider.setDateRange(picked);
  }

  Future<void> _openFilterSheet() async {
    final provider = context.read<VendorsProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final media = MediaQuery.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              16 + media.viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _pickDateRange();
                  },
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    provider.dateRange == null
                        ? 'Filter by date'
                        : '${_dateFmt.format(provider.dateRange!.start)} – ${_dateFmt.format(provider.dateRange!.end)}',
                  ),
                ),
                if (provider.dateRange != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await provider.setDateRange(null);
                    },
                    child: const Text('Clear dates'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<VendorsProvider>();
    final hasFilter = provider.dateRange != null;
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isLoading ? null : provider.refresh,
            icon: const Icon(Icons.refresh_rounded),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: VendorsSearchBar(
                        controller: _searchController,
                        onChanged: provider.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    VendorsFilterButton(
                      active: hasFilter,
                      onTap: _openFilterSheet,
                    ),
                  ],
                ),
              ),
            ),
            if (provider.dateRange != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(
                        '${_dateFmt.format(provider.dateRange!.start)} – ${_dateFmt.format(provider.dateRange!.end)}',
                      ),
                      onDeleted: () => provider.setDateRange(null),
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          AppColors.emerald.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: AppColors.emerald.withValues(alpha: 0.2),
                      ),
                    ),
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
