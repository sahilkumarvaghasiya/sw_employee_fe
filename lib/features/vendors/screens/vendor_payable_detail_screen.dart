import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../stock_entry/models/vendor.dart';
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
  String _infoPendingDisplay = '';

  List<VendorBill> _pendingBills = const [];
  bool _loadingPending = true;
  bool _loadingMorePending = false;
  bool _pendingHasMore = false;
  int _pendingPage = 1;
  String? _pendingError;

  List<VendorStatementEntry> _statementEntries = const [];
  bool _loadingStatement = true;
  bool _loadingMoreStatement = false;
  bool _statementHasMore = false;
  int _statementPage = 1;
  String? _statementError;
  bool _downloadingStatementPdf = false;
  DateTimeRange? _pendingDateRange;

  @override
  void initState() {
    super.initState();
    _infoPendingDisplay = widget.group.pendingDisplay;
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVendorInfo();
      _loadPendingBills();
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

  int? get _vendorId {
    final fromGroup = widget.group.vendorId;
    if (fromGroup != null && fromGroup > 0) return fromGroup;
    return int.tryParse(_vendorInfo?.id.trim() ?? '');
  }

  Future<void> _loadVendorInfo() async {
    setState(() => _loadingInfo = true);
    try {
      final vendorId = _vendorId;
      if (vendorId == null) {
        throw StateError('Missing vendor id');
      }

      final json =
          await VendorsPaymentsService().fetchPayableVendorInfo(vendorId);
      final vendor = Vendor.fromJson(json);
      if (!mounted) return;
      setState(() {
        _vendorInfo = vendor;
        _infoPendingDisplay =
            (json['total_pending'] ?? widget.group.pendingDisplay).toString();
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

  Future<void> _loadPendingBills({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loadingPending = true;
        _pendingError = null;
        _pendingPage = 1;
        _pendingHasMore = false;
      });
    } else {
      if (_loadingMorePending || !_pendingHasMore || _loadingPending) return;
      setState(() => _loadingMorePending = true);
    }

    try {
      final vendorId = _vendorId;
      if (vendorId == null) {
        throw StateError('Missing vendor id');
      }

      final page = await VendorsPaymentsService().fetchPayablePendingBillsPage(
        vendorId: vendorId,
        startDate: _pendingDateRange?.start,
        endDate: _pendingDateRange?.end,
        page: reset ? 1 : _pendingPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pendingBills = page.bills;
          _pendingPage = 2;
        } else {
          _pendingBills = [..._pendingBills, ...page.bills];
          _pendingPage += 1;
        }
        _pendingHasMore = page.hasNext;
        _loadingPending = false;
        _loadingMorePending = false;
        _pendingError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pendingError = 'Couldn’t load pending bills';
          _pendingBills = const [];
        }
        _loadingPending = false;
        _loadingMorePending = false;
      });
    }
  }

  Future<void> _loadStatement({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loadingStatement = true;
        _statementError = null;
        _statementPage = 1;
        _statementHasMore = false;
      });
    } else {
      if (_loadingMoreStatement || !_statementHasMore || _loadingStatement) {
        return;
      }
      setState(() => _loadingMoreStatement = true);
    }

    try {
      final vendorId = _vendorId;
      if (vendorId == null) {
        throw StateError('Missing vendor id');
      }
      final page = await VendorsPaymentsService().fetchPayableStatementPage(
        vendorId: vendorId,
        page: reset ? 1 : _statementPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _statementEntries = page.entries;
          _statementPage = 2;
        } else {
          _statementEntries = [..._statementEntries, ...page.entries];
          _statementPage += 1;
        }
        _statementHasMore = page.hasNext;
        _loadingStatement = false;
        _loadingMoreStatement = false;
        _statementError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _statementError = 'Couldn’t load statement';
          _statementEntries = const [];
        }
        _loadingStatement = false;
        _loadingMoreStatement = false;
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
      final vendorId = _vendorId;
      if (vendorId == null) {
        throw StateError('Missing vendor id');
      }

      final payResult = await context.read<VendorsProvider>().payVendorBills(
            vendorId: vendorId,
            billIds: result.billIds,
            amount: result.amount,
            discount: result.discount,
            surcharge: result.surcharge,
            paymentDate: result.paymentDate,
          );
      if (!mounted) return;

      setState(() => _selectedIds.clear());
      await Future.wait([
        _loadVendorInfo(),
        _loadPendingBills(),
        _loadStatement(),
      ]);
      if (!mounted) return;

      _tabController.animateTo(2);

      final appliedBills = payResult.bills.isNotEmpty
          ? payResult.bills
          : bills.where((b) => result.billIds.contains(b.id)).toList();

      await showPaymentReceiptSheet(
        context: context,
        vendorName: widget.group.displayName,
        amountDisplay: payResult.payment.amountDisplay,
        bills: appliedBills,
        discount: payResult.payment.discount,
        surcharge: payResult.payment.surcharge,
        allocations: payResult.payment.allocations,
      );
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

  String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickPendingDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime? start = _pendingDateRange?.start;
    DateTime? end = _pendingDateRange?.end;

    DateTime clamp(DateTime d) {
      if (d.isBefore(firstDate)) return firstDate;
      if (d.isAfter(lastDate)) return lastDate;
      return d;
    }

    if (start != null) start = clamp(start);
    if (end != null) end = clamp(end);
    if (start != null && end != null && end.isBefore(start)) {
      end = start;
    }

    final picked = await showDialog<_PendingDateChoice?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStart() async {
              final next = await showDatePicker(
                context: dialogContext,
                initialDate: start ?? lastDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (next == null) return;
              setDialogState(() {
                start = clamp(next);
                if (end != null && end!.isBefore(start!)) {
                  end = start;
                }
              });
            }

            Future<void> pickEnd() async {
              final next = await showDatePicker(
                context: dialogContext,
                initialDate: end ?? start ?? lastDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (next == null) return;
              setDialogState(() {
                end = clamp(next);
                if (start != null && end!.isBefore(start!)) {
                  start = end;
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              title: Text(
                'Date range',
                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Start date'),
                    subtitle: Text(
                      start == null ? 'Optional · All dates' : _ddMMyyyy(start!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('End date'),
                    subtitle: Text(
                      end == null ? 'Optional · All dates' : _ddMMyyyy(end!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickEnd,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      const _PendingDateChoice(),
                    );
                  },
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _PendingDateChoice(start: start, end: end),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (picked.start != null && picked.end != null) {
        _pendingDateRange = DateTimeRange(
          start: picked.start!,
          end: picked.end!,
        );
      } else if (picked.start == null && picked.end == null) {
        _pendingDateRange = null;
      } else {
        // Partial range: treat missing side as open-ended via a wide bound.
        final resolvedStart = picked.start ?? firstDate;
        final resolvedEnd = picked.end ?? lastDate;
        _pendingDateRange = DateTimeRange(
          start: resolvedStart,
          end: resolvedEnd.isBefore(resolvedStart) ? resolvedStart : resolvedEnd,
        );
      }
      _selectedIds.clear();
    });
    await _loadPendingBills();
  }

  Future<_StatementDateChoice?> _askStatementDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime? start;
    DateTime? end;

    DateTime clamp(DateTime d) {
      if (d.isBefore(firstDate)) return firstDate;
      if (d.isAfter(lastDate)) return lastDate;
      return d;
    }

    return showDialog<_StatementDateChoice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStart() async {
              final next = await showDatePicker(
                context: dialogContext,
                initialDate: start ?? lastDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (next == null) return;
              setDialogState(() {
                start = clamp(next);
                if (end != null && end!.isBefore(start!)) {
                  end = start;
                }
              });
            }

            Future<void> pickEnd() async {
              final next = await showDatePicker(
                context: dialogContext,
                initialDate: end ?? start ?? lastDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (next == null) return;
              setDialogState(() {
                end = clamp(next);
                if (start != null && end!.isBefore(start!)) {
                  start = end;
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              title: Text(
                'Statement period',
                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Start date'),
                    subtitle: Text(
                      start == null
                          ? 'Optional · Default last 6 months'
                          : _ddMMyyyy(start!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('End date'),
                    subtitle: Text(
                      end == null
                          ? 'Optional · Default today'
                          : _ddMMyyyy(end!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickEnd,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      start = null;
                      end = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _StatementDateChoice(start: start, end: end),
                    );
                  },
                  child: const Text('Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadStatementPdf() async {
    if (_downloadingStatementPdf) return;

    var vendorId = _vendorId;
    if (vendorId == null) {
      await _loadVendorInfo();
      if (!mounted) return;
      vendorId = _vendorId;
    }
    if (vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t resolve this vendor for PDF download'),
        ),
      );
      return;
    }

    final choice = await _askStatementDateRange();
    if (choice == null || !mounted) return;

    // Default: last 6 months when both dates are empty.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final defaultStart = DateTime(today.year, today.month - 6, today.day);
    final startDate = choice.start ?? defaultStart;
    final endDate = choice.end ?? today;

    setState(() => _downloadingStatementPdf = true);
    try {
      final bytes = await context.read<VendorsProvider>().fetchReportPdf(
            startDate: startDate,
            endDate: endDate,
            vendorId: vendorId,
          );
      if (!mounted) return;

      final safeName = widget.group.vendorName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final filename =
          'vendor-statement-${safeName.isEmpty ? 'vendor' : safeName}-'
          '${DateFormat('yyyyMMdd').format(startDate)}-'
          '${DateFormat('yyyyMMdd').format(endDate)}.pdf';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download statement PDF')),
      );
    } finally {
      if (mounted) setState(() => _downloadingStatementPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<VendorsProvider>();
    final live = provider.vendorByName(widget.group.vendorName) ?? widget.group;
    final bills = _pendingBills;
    final hasPendingDateFilter = _pendingDateRange != null;
    final outstandingDisplay = _infoPendingDisplay.isNotEmpty
        ? _infoPendingDisplay
        : live.pendingDisplay;
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
                        outstandingDisplay,
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
            pendingDisplay: outstandingDisplay,
            vendor: _vendorInfo,
            loading: _loadingInfo,
            onRetry: _loadVendorInfo,
          ),
          _PendingPaymentsTab(
            bills: bills,
            loading: _loadingPending,
            loadingMore: _loadingMorePending,
            hasMore: _pendingHasMore,
            error: _pendingError,
            selectedIds: _selectedIds,
            hasDateFilter: hasPendingDateFilter,
            onPickDateRange: _pickPendingDateRange,
            onRetry: () => _loadPendingBills(reset: true),
            onLoadMore: () => _loadPendingBills(reset: false),
            onToggle: _toggle,
            onOpenDetails: (bill) async {
              await Navigator.of(context).push(
                VendorBillDetailScreen.route(
                  bill: bill,
                  provider: provider,
                ),
              );
              if (!mounted) return;
              await _loadPendingBills(reset: true);
            },
          ),
          _StatementTab(
            entries: _statementEntries,
            loading: _loadingStatement,
            loadingMore: _loadingMoreStatement,
            hasMore: _statementHasMore,
            error: _statementError,
            downloadingPdf: _downloadingStatementPdf,
            onRetry: () => _loadStatement(reset: true),
            onLoadMore: () => _loadStatement(reset: false),
            onOpenPurchase: (bill) async {
              await Navigator.of(context).push(
                VendorBillDetailScreen.route(
                  bill: bill,
                  provider: provider,
                ),
              );
            },
            onOpenPayment: (payment) async {
              var detail = payment;
              final paymentId = int.tryParse(payment.id);
              if (paymentId != null) {
                try {
                  detail = await VendorsPaymentsService()
                      .fetchPayablePaymentDetail(paymentId);
                } catch (_) {}
              }
              if (!mounted) return;
              showStatementPaymentDetailSheet(
                context: context,
                payment: detail,
              );
            },
            onDownloadPdf: _downloadStatementPdf,
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

class _PendingPaymentsTab extends StatefulWidget {
  const _PendingPaymentsTab({
    required this.bills,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.selectedIds,
    required this.hasDateFilter,
    required this.onPickDateRange,
    required this.onRetry,
    required this.onLoadMore,
    required this.onToggle,
    required this.onOpenDetails,
  });

  final List<VendorBill> bills;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final Set<int> selectedIds;
  final bool hasDateFilter;
  final VoidCallback onPickDateRange;
  final VoidCallback onRetry;
  final Future<void> Function() onLoadMore;
  final ValueChanged<int> onToggle;
  final ValueChanged<VendorBill> onOpenDetails;

  @override
  State<_PendingPaymentsTab> createState() => _PendingPaymentsTabState();
}

class _PendingPaymentsTabState extends State<_PendingPaymentsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _postFramePaginationScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() => _maybeLoadMore();

  void _maybeLoadMore() {
    if (!mounted) return;
    if (!widget.hasMore || widget.loading || widget.loadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldLoad = position.maxScrollExtent <= 0 ||
        position.pixels >= (position.maxScrollExtent - 240);
    if (!shouldLoad) return;

    unawaited(widget.onLoadMore());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bills = widget.bills;
    final loading = widget.loading;
    final error = widget.error;
    final hasDateFilter = widget.hasDateFilter;

    // Products-style: if first page doesn't fill viewport, keep fetching.
    if (!_postFramePaginationScheduled &&
        bills.isNotEmpty &&
        widget.hasMore &&
        !loading &&
        !widget.loadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent <= 0) {
      _postFramePaginationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFramePaginationScheduled = false;
        if (!mounted) return;
        _maybeLoadMore();
      });
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
            ),
            IconButton(
              tooltip: hasDateFilter ? 'Change date filter' : 'Filter by date',
              onPressed: widget.onPickDateRange,
              icon: Badge(
                isLabelVisible: hasDateFilter,
                smallSize: 8,
                child: Icon(
                  Icons.date_range_outlined,
                  color: hasDateFilter
                      ? AppColors.emerald
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: VendorsEmptyState(
              title: 'Couldn’t load pending bills',
              subtitle: 'Pull or tap retry',
              actionLabel: 'Retry',
              onAction: widget.onRetry,
              icon: Icons.error_outline_rounded,
            ),
          )
        else if (bills.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: VendorsEmptyState(
              title: hasDateFilter
                  ? 'No bills in this period'
                  : 'No pending payments',
              subtitle: hasDateFilter
                  ? 'Try a different date range'
                  : 'All bills for this vendor are settled',
            ),
          )
        else ...[
          ...bills.map(
            (bill) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VendorBillSelectTile(
                bill: bill,
                selected: widget.selectedIds.contains(bill.id),
                onToggle: () => widget.onToggle(bill.id),
                onOpenDetails: () => widget.onOpenDetails(bill),
              ),
            ),
          ),
          _ListPaginationFooter(
            isLoadingMore: widget.loadingMore,
            hasMore: widget.hasMore,
            doneLabel: 'All bills loaded',
          ),
        ],
      ],
    );
  }
}

class _StatementTab extends StatefulWidget {
  const _StatementTab({
    required this.entries,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.downloadingPdf,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenPurchase,
    required this.onOpenPayment,
    required this.onDownloadPdf,
  });

  final List<VendorStatementEntry> entries;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final bool downloadingPdf;
  final VoidCallback onRetry;
  final Future<void> Function() onLoadMore;
  final ValueChanged<VendorBill> onOpenPurchase;
  final ValueChanged<VendorStatementPayment> onOpenPayment;
  final VoidCallback onDownloadPdf;

  @override
  State<_StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends State<_StatementTab> {
  final ScrollController _scrollController = ScrollController();
  static final DateFormat _paymentDateFmt = DateFormat('dd MMM yyyy · hh:mm a');
  bool _postFramePaginationScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() => _maybeLoadMore();

  void _maybeLoadMore() {
    if (!mounted) return;
    if (!widget.hasMore || widget.loading || widget.loadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldLoad = position.maxScrollExtent <= 0 ||
        position.pixels >= (position.maxScrollExtent - 240);
    if (!shouldLoad) return;

    unawaited(widget.onLoadMore());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entries = widget.entries;
    final loading = widget.loading;
    final error = widget.error;
    final downloadingPdf = widget.downloadingPdf;

    if (!_postFramePaginationScheduled &&
        entries.isNotEmpty &&
        widget.hasMore &&
        !loading &&
        !widget.loadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent <= 0) {
      _postFramePaginationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFramePaginationScheduled = false;
        if (!mounted) return;
        _maybeLoadMore();
      });
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && entries.isEmpty) {
      return VendorsEmptyState(
        title: error,
        subtitle: 'Pull to retry or tap below',
        actionLabel: 'Retry',
        onAction: widget.onRetry,
        icon: Icons.error_outline_rounded,
      );
    }

    if (entries.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: VendorsEmptyState(
              title: 'No statement entries',
              subtitle: 'Purchases and payments will show here',
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _StatementPdfButton(
                downloading: downloadingPdf,
                onPressed: widget.onDownloadPdf,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: entries.length + 2,
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

              if (index == entries.length + 1) {
                return _ListPaginationFooter(
                  isLoadingMore: widget.loadingMore,
                  hasMore: widget.hasMore,
                  doneLabel: 'All statement entries loaded',
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
                  onTap: () => widget.onOpenPayment(payment),
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
                onTap: () => widget.onOpenPurchase(bill),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _StatementPdfButton(
              downloading: downloadingPdf,
              onPressed: widget.onDownloadPdf,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListPaginationFooter extends StatelessWidget {
  const _ListPaginationFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.doneLabel,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (!hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            doneLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatementPdfButton extends StatelessWidget {
  const _StatementPdfButton({
    required this.downloading,
    required this.onPressed,
  });

  final bool downloading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: downloading ? null : onPressed,
      icon: downloading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(downloading ? 'Preparing PDF…' : 'Download PDF statement'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.emerald,
        side: const BorderSide(color: AppColors.emerald, width: 1.4),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _StatementDateChoice {
  const _StatementDateChoice({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}

class _PendingDateChoice {
  const _PendingDateChoice({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}
