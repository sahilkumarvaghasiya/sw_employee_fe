import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../stock_entry/models/vendor.dart';
import '../../stock_entry/services/vendors_service.dart';
import '../models/vendor_bill.dart';
import '../providers/vendors_provider.dart';
import '../services/vendors_payments_service.dart';
import '../widgets/vendors_ui.dart';
import 'vendor_bill_detail_screen.dart';
import 'vendor_new_payment_screen.dart';

class VendorPayableDetailScreen extends StatefulWidget {
  const VendorPayableDetailScreen({
    super.key,
    required this.group,
  });

  final VendorPayableGroup group;

  static Route<void> route({
    required VendorPayableGroup group,
    required VendorsProvider provider,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: '/vendors/payable/${group.vendorName}'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: VendorPayableDetailScreen(group: group),
      ),
    );
  }

  @override
  State<VendorPayableDetailScreen> createState() =>
      _VendorPayableDetailScreenState();
}

class _VendorPayableDetailScreenState extends State<VendorPayableDetailScreen>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedIds = <int>{};
  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');

  late final TabController _tabController;

  Vendor? _vendorInfo;
  bool _loadingInfo = true;

  List<VendorBill> _statementBills = const [];
  bool _loadingStatement = true;
  String? _statementError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVendorInfo();
      _loadStatement();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadVendorInfo() async {
    setState(() => _loadingInfo = true);
    try {
      final vendors = await VendorsService().fetchVendors();
      final key = widget.group.vendorName.trim().toLowerCase();
      Vendor? match;
      for (final v in vendors) {
        final name = v.name.trim().toLowerCase();
        if (name == key) {
          match = v;
          break;
        }
      }
      if (match == null) {
        for (final v in vendors) {
          final name = v.name.trim().toLowerCase();
          if (name.contains(key) || key.contains(name)) {
            match = v;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _vendorInfo = match;
        _loadingInfo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vendorInfo = null;
        _loadingInfo = false;
      });
    }
  }

  Future<void> _loadStatement() async {
    setState(() {
      _loadingStatement = true;
      _statementError = null;
    });
    try {
      final service = VendorsPaymentsService();
      final bills = <VendorBill>[];
      for (final status in ['unpaid', 'partial', 'paid']) {
        var page = 1;
        while (true) {
          final result = await service.fetchBills(
            search: widget.group.vendorName,
            status: status,
            sort: 'newest',
            page: page,
            pageSize: 100,
          );
          bills.addAll(
            result.bills.where(
              (b) =>
                  b.vendor.trim().toLowerCase() ==
                  widget.group.vendorName.trim().toLowerCase(),
            ),
          );
          if (!result.hasNext) break;
          page += 1;
          if (page > 20) break;
        }
      }
      bills.sort((a, b) => b.billDate.compareTo(a.billDate));
      if (!mounted) return;
      setState(() {
        _statementBills = bills;
        _loadingStatement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statementError = 'Couldn’t load statement';
        _loadingStatement = false;
      });
    }
  }

  void _toggle(int billId) {
    setState(() {
      if (_selectedIds.contains(billId)) {
        _selectedIds.remove(billId);
      } else {
        _selectedIds.add(billId);
      }
    });
  }

  void _selectAll(List<VendorBill> bills) {
    setState(() {
      if (_selectedIds.length == bills.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(bills.map((b) => b.id));
      }
    });
  }

  Future<void> _paySelected(List<VendorBill> bills) async {
    final selected = bills
        .where((b) => _selectedIds.contains(b.id))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final live = context.read<VendorsProvider>().vendorByName(
          widget.group.vendorName,
        ) ??
        widget.group;

    final result = await Navigator.of(context).push<NewPaymentResult?>(
      VendorNewPaymentScreen.route(
        vendorName: live.vendorName,
        pendingDisplay: live.pendingDisplay,
        pendingAmount: live.pendingAmount,
        bills: bills,
        provider: context.read<VendorsProvider>(),
        initialSelectedIds: {..._selectedIds},
      ),
    );
    if (result == null || !mounted) return;

    try {
      await context.read<VendorsProvider>().bulkPay(
            billIds: result.billIds,
            amount: result.amount,
          );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      await _loadStatement();
      if (!mounted) return;

      final paidBills =
          bills.where((b) => result.billIds.contains(b.id)).toList();
      await showPaymentReceiptSheet(
        context: context,
        vendorName: widget.group.displayName,
        amountDisplay: _inr.format(result.amount),
        bills: paidBills,
        discount: result.discount,
        surcharge: result.surcharge,
      );

      if (result.printPdf && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment PDF export will use a dedicated API next.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('ClientException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<VendorsProvider>();
    final live = provider.vendorByName(widget.group.vendorName) ?? widget.group;
    final bills = live.bills.where((b) => !b.isFullyPaid).toList();
    final validIds = bills.map((b) => b.id).toSet();
    final selectedBills =
        bills.where((b) => _selectedIds.contains(b.id)).toList();
    final selectedTotal =
        selectedBills.fold<double>(0, (sum, b) => sum + b.pendingAmount);
    final selectedTotalDisplay = _inr.format(selectedTotal);
    final allSelected = bills.isNotEmpty &&
        _selectedIds.intersection(validIds).length == bills.length;
    final showPayBar =
        _tabController.index == 1 && selectedBills.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pay Vendor'),
        actions: [
          if (_tabController.index == 1 && bills.isNotEmpty)
            TextButton(
              onPressed: () => _selectAll(bills),
              child: Text(allSelected ? 'Clear' : 'Select all'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        live.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InrAmountText(
                      live.pendingDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.emerald,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: AppColors.emerald,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
                unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                tabs: const [
                  Tab(text: 'INFORMATION'),
                  Tab(text: 'PENDING PAYMENTS'),
                  Tab(text: 'STATEMENT'),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showPayBar
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedBills.length} selected',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InrAmountText(
                            selectedTotalDisplay,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: provider.isPaying
                          ? null
                          : () => _paySelected(bills),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                      ),
                      child: Text(provider.isPaying ? 'Saving…' : 'Pay'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _InformationTab(
            vendorName: live.displayName,
            pendingDisplay: live.pendingDisplay,
            vendor: _vendorInfo,
            loading: _loadingInfo,
            onRetry: _loadVendorInfo,
          ),
          _PendingPaymentsTab(
            bills: bills,
            selectedIds: _selectedIds,
            onToggle: _toggle,
            onOpenDetails: (bill) async {
              await Navigator.of(context).push(
                VendorBillDetailScreen.route(
                  bill: bill,
                  provider: provider,
                ),
              );
            },
          ),
          _StatementTab(
            bills: _statementBills,
            loading: _loadingStatement,
            error: _statementError,
            onRetry: _loadStatement,
            onViewFull: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Full statement PDF needs a dedicated API — coming next.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InformationTab extends StatelessWidget {
  const _InformationTab({
    required this.vendorName,
    required this.pendingDisplay,
    required this.vendor,
    required this.loading,
    required this.onRetry,
  });

  final String vendorName;
  final String pendingDisplay;
  final Vendor? vendor;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rows = <(String, String)>[
      ('Name', vendorName),
      ('Phone', (vendor?.phone.trim().isNotEmpty ?? false)
          ? vendor!.phone
          : '—'),
      ('GST', (vendor?.gst.trim().isNotEmpty ?? false) ? vendor!.gst : '—'),
      ('Email', vendor?.email?.trim().isNotEmpty == true ? vendor!.email! : '—'),
      (
        'Address',
        vendor?.address?.trim().isNotEmpty == true ? vendor!.address! : '—',
      ),
      ('Pending', '₹ $pendingDisplay'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          rows[i].$1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (vendor == null) ...[
          const SizedBox(height: 16),
          Text(
            'More vendor profile fields can be wired when the contact API is expanded.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry lookup'),
          ),
        ],
      ],
    );
  }
}

class _PendingPaymentsTab extends StatelessWidget {
  const _PendingPaymentsTab({
    required this.bills,
    required this.selectedIds,
    required this.onToggle,
    required this.onOpenDetails,
  });

  final List<VendorBill> bills;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;
  final ValueChanged<VendorBill> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (bills.isEmpty) {
      return const VendorsEmptyState(
        title: 'No pending payments',
        subtitle: 'All bills for this vendor are settled',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Select bills to pay',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose one or more purchases, then pay a single amount',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        ...bills.map((bill) {
          final selected = selectedIds.contains(bill.id);
          final daysLabel = bill.due.days != null
              ? 'Days: ${bill.due.days}'
              : bill.due.label;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppSurfaceCard(
              onTap: () => onToggle(bill.id),
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
              borderColor: selected
                  ? AppColors.emerald.withValues(alpha: 0.45)
                  : null,
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(bill.id),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase#${bill.stkNo}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bill.billDate}  ($daysLabel)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: bill.due.isOverdue
                                ? AppColors.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit / details',
                    onPressed: () => onOpenDetails(bill),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InrAmountText(
                        bill.pendingDisplay,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC2410C),
                        ),
                      ),
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: const Color(0xFFF97316),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatementTab extends StatelessWidget {
  const _StatementTab({
    required this.bills,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onViewFull,
  });

  final List<VendorBill> bills;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return VendorsEmptyState(
        title: error!,
        subtitle: 'Pull to retry or tap below',
        actionLabel: 'Retry',
        onAction: onRetry,
        icon: Icons.error_outline_rounded,
      );
    }

    if (bills.isEmpty) {
      return const VendorsEmptyState(
        title: 'No statement entries',
        subtitle: 'Purchases and payments will show here',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: bills.length + 1,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    'Purchases from bills. Payment ledger needs a dedicated API.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final bill = bills[index - 1];
              return StatementEntryTile(
                title: 'Purchase#${bill.stkNo}',
                subtitle: [
                  bill.billDate,
                  if (bill.statusDisplay.isNotEmpty) bill.statusDisplay,
                ].join(' · '),
                amountDisplay: bill.totalDisplay,
                kind: StatementEntryKind.purchase,
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton(
              onPressed: onViewFull,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald,
                side: const BorderSide(color: AppColors.emerald, width: 1.4),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('VIEW FULL STATEMENT'),
            ),
          ),
        ),
      ],
    );
  }
}
