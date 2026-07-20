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
  final List<VendorStatementPayment> _sessionPayments = [];
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

      final paidBills =
          bills.where((b) => result.billIds.contains(b.id)).toList();
      final payment = VendorStatementPayment(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        paidAt: result.paymentDate,
        amount: result.amount,
        amountDisplay: _inr.format(result.amount),
        bills: List.unmodifiable(paidBills),
        discount: result.discount,
        surcharge: result.surcharge,
      );

      setState(() {
        _selectedIds.clear();
        _sessionPayments.insert(0, payment);
      });
      await _loadStatement();
      if (!mounted) return;

      _tabController.animateTo(2);

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

  DateTime _parseBillSortDate(String raw) {
    final formats = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd MMM yyyy'),
    ];
    for (final format in formats) {
      try {
        return format.parse(raw);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<VendorStatementEntry> get _statementEntries {
    final entries = <VendorStatementEntry>[
      for (final payment in _sessionPayments)
        VendorStatementEntry.payment(
          payment: payment,
          sortAt: payment.paidAt,
        ),
      for (final bill in _statementBills)
        VendorStatementEntry.purchase(
          bill: bill,
          sortAt: _parseBillSortDate(bill.billDate),
        ),
    ];
    entries.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return entries;
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
          preferredSize: const Size.fromHeight(110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppSurfaceCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              live.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Outstanding balance',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InrAmountText(
                        live.pendingDisplay,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ],
                  ),
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
                  letterSpacing: 0.4,
                ),
                unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Statement'),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showPayBar
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
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
            entries: _statementEntries,
            loading: _loadingStatement,
            error: _statementError,
            onRetry: _loadStatement,
            onOpenPurchase: (bill) async {
              await Navigator.of(context).push(
                VendorBillDetailScreen.route(
                  bill: bill,
                  provider: provider,
                ),
              );
            },
            onOpenPayment: (payment) {
              showStatementPaymentDetailSheet(
                context: context,
                payment: payment,
              );
            },
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
        ...bills.map(
          (bill) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VendorBillSelectTile(
              bill: bill,
              selected: selectedIds.contains(bill.id),
              onToggle: () => onToggle(bill.id),
              onOpenDetails: () => onOpenDetails(bill),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatementTab extends StatelessWidget {
  const _StatementTab({
    required this.entries,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onOpenPurchase,
    required this.onOpenPayment,
    required this.onViewFull,
  });

  final List<VendorStatementEntry> entries;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<VendorBill> onOpenPurchase;
  final ValueChanged<VendorStatementPayment> onOpenPayment;
  final VoidCallback onViewFull;

  static final DateFormat _paymentDateFmt = DateFormat('dd MMM yyyy · hh:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && entries.isEmpty) {
      return VendorsEmptyState(
        title: error!,
        subtitle: 'Pull to retry or tap below',
        actionLabel: 'Retry',
        onAction: onRetry,
        icon: Icons.error_outline_rounded,
      );
    }

    if (entries.isEmpty) {
      return const VendorsEmptyState(
        title: 'No statement entries',
        subtitle: 'Purchases and payments will show here',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Tap a payment to see which bills were settled.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }

              final entry = entries[index - 1];
              if (entry.kind == VendorStatementKind.payment) {
                final payment = entry.payment!;
                final billLabel =
                    '${payment.billCount} bill${payment.billCount == 1 ? '' : 's'}';
                final adjustmentBits = <String>[
                  if (payment.discount > 0) 'Discount',
                  if (payment.surcharge > 0) 'Surcharge',
                ];

                return StatementEntryTile(
                  title: 'Payment',
                  subtitle: _paymentDateFmt.format(payment.paidAt),
                  amountDisplay: payment.amountDisplay,
                  amountPrefix: '− ',
                  kind: StatementEntryKind.payment,
                  trailingLabel: adjustmentBits.isEmpty
                      ? billLabel
                      : '$billLabel · ${adjustmentBits.join(' · ')}',
                  onTap: () => onOpenPayment(payment),
                );
              }

              final bill = entry.bill!;
              return StatementEntryTile(
                title: 'Purchase #${bill.stkNo}',
                subtitle: [
                  bill.billDate,
                  if (bill.statusDisplay.isNotEmpty) bill.statusDisplay,
                ].join(' · '),
                amountDisplay: bill.totalDisplay,
                kind: StatementEntryKind.purchase,
                onTap: () => onOpenPurchase(bill),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('View full statement'),
            ),
          ),
        ),
      ],
    );
  }
}
