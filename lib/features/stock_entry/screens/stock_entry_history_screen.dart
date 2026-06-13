import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import '../widgets/stock_entry_ui.dart';
import 'stock_entry_detail_screen.dart';

enum _PaymentFilter { paid, halfPaid, unpaid }

abstract class _DateRangeDialogResult {
  const _DateRangeDialogResult();
}

class _DateRangeApplied extends _DateRangeDialogResult {
  const _DateRangeApplied(this.range);

  final DateTimeRange range;
}

class _DateRangeCleared extends _DateRangeDialogResult {
  const _DateRangeCleared();
}

class StockEntryHistoryScreen extends StatefulWidget {
  const StockEntryHistoryScreen({super.key, this.vendor});

  final Vendor? vendor;

  static const String routeName = '/stock-entry/history';

  static Route<void> route({Vendor? vendor}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockEntryHistoryScreen(vendor: vendor),
    );
  }

  @override
  State<StockEntryHistoryScreen> createState() =>
      _StockEntryHistoryScreenState();
}

class _StockEntryHistoryScreenState extends State<StockEntryHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _didRequestInitialHistory = false;

  _PaymentFilter _paymentFilter = _PaymentFilter.unpaid;
  DateTimeRange? _dateRange;

  String _paymentLabel(_PaymentFilter filter) {
    switch (filter) {
      case _PaymentFilter.paid:
        return 'Paid';
      case _PaymentFilter.halfPaid:
        return 'Half paid';
      case _PaymentFilter.unpaid:
        return 'Unpaid';
    }
  }

  void _clearFilters() {
    setState(() {
      _paymentFilter = _PaymentFilter.unpaid;
      _dateRange = null;
    });
  }

  String _backendStatusParam(_PaymentFilter filter) {
    switch (filter) {
      case _PaymentFilter.paid:
        return 'paid';
      case _PaymentFilter.halfPaid:
        // Backend uses "partial".
        return 'partial';
      case _PaymentFilter.unpaid:
        return 'unpaid';
    }
  }

  Future<void> _refreshBackendHistory() async {
    final vendor = widget.vendor;
    if (vendor == null) return;

    await context.read<StockEntryProvider>().refreshHistory(
      vendor: vendor,
      status: _backendStatusParam(_paymentFilter),
      dateRange: _dateRange,
    );
  }

  int _activeFilterCount() {
    var count = 0;
    if (_paymentFilter != _PaymentFilter.unpaid) count++;
    if (_dateRange != null) count++;
    return count;
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final media = MediaQuery.of(context);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              16 + media.viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filter entries',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payment status and date range',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment status',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_PaymentFilter>(
                      segments: [
                        ButtonSegment(
                          value: _PaymentFilter.paid,
                          label: Text(
                            _paymentLabel(_PaymentFilter.paid),
                            style: theme.textTheme.labelSmall,
                          ),
                          icon: Icon(
                            _statusIcon(_PaymentFilter.paid),
                            size: 16,
                          ),
                        ),
                        ButtonSegment(
                          value: _PaymentFilter.halfPaid,
                          label: Text(
                            _paymentLabel(_PaymentFilter.halfPaid),
                            style: theme.textTheme.labelSmall,
                          ),
                          icon: Icon(
                            _statusIcon(_PaymentFilter.halfPaid),
                            size: 16,
                          ),
                        ),
                        ButtonSegment(
                          value: _PaymentFilter.unpaid,
                          label: Text(
                            _paymentLabel(_PaymentFilter.unpaid),
                            style: theme.textTheme.labelSmall,
                          ),
                          icon: Icon(
                            _statusIcon(_PaymentFilter.unpaid),
                            size: 16,
                          ),
                        ),
                      ],
                      selected: {_paymentFilter},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _paymentFilter = selection.first);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Date range',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _pickDateRange();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _rangeLabel(context, _dateRange),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                    if (_dateRange != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() => _dateRange = null);
                            setModalState(() {});
                          },
                          child: const Text('Clear date'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _clearFilters();
                            setModalState(() {});
                            unawaited(_refreshBackendHistory());
                            Navigator.of(context).pop();
                          },
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(_refreshBackendHistory());
                          },
                          child: const Text('Apply filters'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;

      if (position.pixels >= position.maxScrollExtent - 320) {
        context.read<StockEntryProvider>().loadMoreHistory();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final vendor = widget.vendor;
    if (vendor == null) return;
    if (_didRequestInitialHistory) return;
    _didRequestInitialHistory = true;

    // Load vendor-specific history from backend when opening this screen.
    Future.microtask(() {
      if (!mounted) return;
      context.read<StockEntryProvider>().refreshHistory(
        vendor: vendor,
        status: _backendStatusParam(_paymentFilter),
        dateRange: _dateRange,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _money(double value) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _rangeLabel(BuildContext context, DateTimeRange? range) {
    if (range == null) return 'Select date range';
    return '${_ddMMyyyy(range.start)} – ${_ddMMyyyy(range.end)}';
  }

  IconData _statusIcon(_PaymentFilter filter) {
    switch (filter) {
      case _PaymentFilter.paid:
        return Icons.check_circle_outline_rounded;
      case _PaymentFilter.halfPaid:
        return Icons.timelapse_outlined;
      case _PaymentFilter.unpaid:
        return Icons.warning_amber_rounded;
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  bool _isPaid(StockEntry entry) =>
      entry.payment.status == PaymentStatus.paid ||
      entry.payment.remainingAmount <= 0;

  bool _isHalfPaid(StockEntry entry) {
    if (_isPaid(entry)) return false;
    return entry.payment.paidAmount > 0.0001;
  }

  bool _isUnpaid(StockEntry entry) {
    if (_isPaid(entry)) return false;
    return entry.payment.paidAmount <= 0.0001;
  }

  List<StockEntry> _applyFilters(List<StockEntry> entries) {
    Iterable<StockEntry> out = entries;

    out = out.where((e) {
      switch (_paymentFilter) {
        case _PaymentFilter.paid:
          return _isPaid(e);
        case _PaymentFilter.halfPaid:
          return _isHalfPaid(e);
        case _PaymentFilter.unpaid:
          return _isUnpaid(e);
      }
    });

    final range = _dateRange;
    if (range != null) {
      final start = _startOfDay(range.start);
      final end = _endOfDay(range.end);
      out = out.where(
        (e) => !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end),
      );
    }

    return out.toList(growable: false);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime? start = _dateRange?.start;
    DateTime? end = _dateRange?.end;

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

    final picked = await showDialog<_DateRangeDialogResult?>(
      context: context,
      builder: (dialogContext) {
        String fmt(DateTime? d) {
          if (d == null) return 'Not set';
          return _ddMMyyyy(d);
        }

        Future<void> pickStart() async {
          final next = await showDatePicker(
            context: dialogContext,
            initialDate: start ?? lastDate,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (next == null) return;
          start = clamp(next);
          if (end != null && end!.isBefore(start!)) {
            end = start;
          }
          (dialogContext as Element).markNeedsBuild();
        }

        Future<void> pickEnd() async {
          final next = await showDatePicker(
            context: dialogContext,
            initialDate: end ?? start ?? lastDate,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (next == null) return;
          end = clamp(next);
          if (start != null && end!.isBefore(start!)) {
            start = end;
          }
          (dialogContext as Element).markNeedsBuild();
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
                subtitle: Text(fmt(start)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('End date'),
                subtitle: Text(fmt(end)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: pickEnd,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                start = null;
                end = null;
                (dialogContext as Element).markNeedsBuild();
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                if (start == null || end == null) {
                  Navigator.of(dialogContext).pop(const _DateRangeCleared());
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _DateRangeApplied(DateTimeRange(start: start!, end: end!)),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || picked == null) return;

    if (picked is _DateRangeCleared) {
      setState(() => _dateRange = null);
      return;
    }

    if (picked is _DateRangeApplied) {
      setState(() => _dateRange = picked.range);
    }
  }

  (String, Color, IconData) _entryStatusUi(StockEntry entry) {
    final remaining = entry.payment.remainingAmount;
    final paid = entry.payment.paidAmount;
    final isPaid = remaining <= 0;
    final isHalfPaid = !isPaid && paid > 0.0001;

    if (isPaid) {
      return (
        'Paid',
        AppColors.emerald,
        Icons.check_circle_outline_rounded,
      );
    }
    if (isHalfPaid) {
      return ('Half paid', AppColors.warning, Icons.timelapse_outlined);
    }
    return ('Unpaid', AppColors.error, Icons.warning_amber_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<StockEntryProvider>();

    final baseEntries = widget.vendor == null
        ? provider.entries
        : provider.entries
              .where((e) => e.vendor.id == widget.vendor!.id)
              .toList(growable: false);

    final filteredEntries = _applyFilters(baseEntries);

    final vendorName = widget.vendor?.name ?? 'All traders';
    final filterCount = _activeFilterCount();
    final hasAnyFilter = filterCount > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Entry history'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (hasAnyFilter)
            TextButton.icon(
              onPressed: () {
                _clearFilters();
                unawaited(_refreshBackendHistory());
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear all'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBackendHistory,
        color: AppColors.emerald,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      vendorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Past stock entries for this vendor',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        StockEntryHistoryFilterButton(
                          activeCount: filterCount,
                          onTap: _openFiltersSheet,
                        ),
                      ],
                    ),
                    if (hasAnyFilter) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_paymentFilter != _PaymentFilter.unpaid)
                              StockEntryHistoryFilterChip(
                                label:
                                    'Payment: ${_paymentLabel(_paymentFilter)}',
                                onRemove: () {
                                  setState(
                                    () => _paymentFilter = _PaymentFilter.unpaid,
                                  );
                                  unawaited(_refreshBackendHistory());
                                },
                              ),
                            if (_dateRange != null) ...[
                              if (_paymentFilter != _PaymentFilter.unpaid)
                                const SizedBox(width: 6),
                              StockEntryHistoryFilterChip(
                                label: _rangeLabel(context, _dateRange),
                                onRemove: () {
                                  setState(() => _dateRange = null);
                                  unawaited(_refreshBackendHistory());
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (provider.isLoadingInitial)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StockEntryHistoryEmptyState(
                  title: 'Could not load history',
                  subtitle: provider.error,
                  actionLabel: 'Try again',
                  onAction: () {
                    final vendor = widget.vendor;
                    if (vendor == null) return;
                    provider.refreshHistory(vendor: vendor);
                  },
                  icon: Icons.cloud_off_outlined,
                ),
              )
            else if (baseEntries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StockEntryHistoryEmptyState(
                  title: 'No entries yet',
                  subtitle: hasAnyFilter
                      ? 'Try changing your filters'
                      : 'Stock entries will appear here after you save',
                  actionLabel: hasAnyFilter ? 'Clear filters' : null,
                  onAction: hasAnyFilter
                      ? () {
                          _clearFilters();
                          unawaited(_refreshBackendHistory());
                        }
                      : null,
                ),
              )
            else if (filteredEntries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StockEntryHistoryEmptyState(
                  title: 'No matching entries',
                  subtitle: 'Try changing payment status or date range',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _clearFilters();
                    unawaited(_refreshBackendHistory());
                  },
                  icon: Icons.search_off_rounded,
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    '${filteredEntries.length} entr${filteredEntries.length == 1 ? 'y' : 'ies'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverList.separated(
                  itemCount: filteredEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    final (statusLabel, statusColor, statusIcon) =
                        _entryStatusUi(entry);
                    final invoiceNo = entry.stknumber?.trim();
                    final due = entry.payment.remainingAmount <= 0
                        ? 0.0
                        : entry.payment.remainingAmount;

                    return StockEntryHistoryTile(
                      invoiceNo: invoiceNo,
                      dateLabel: _ddMMyyyy(entry.createdAt),
                      vendorName: entry.vendor.name,
                      showVendor: widget.vendor == null,
                      totalLabel: _money(entry.payment.totalPayment),
                      paidLabel: _money(entry.payment.paidAmount),
                      dueLabel: _money(due),
                      statusLabel: statusLabel,
                      statusColor: statusColor,
                      statusIcon: statusIcon,
                      onTap: () {
                        Navigator.of(context).push(
                          StockEntryDetailScreen.route(entry: entry),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            if (!provider.isLoadingInitial &&
                provider.error == null &&
                baseEntries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _PaginationFooter(
                    isLoadingMore: provider.isLoadingMore,
                    hasMore: provider.hasMore,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoadingMore, required this.hasMore});

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoadingMore) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading more…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (!hasMore) {
      return Text(
        'All entries loaded',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
