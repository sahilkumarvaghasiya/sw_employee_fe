import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
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

  Widget _filtersSummaryBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final paymentLabel = _paymentLabel(_paymentFilter);
    final statusIcon = _statusIcon(_paymentFilter);
    final statusColor = _statusColor(_paymentFilter);

    final dateRange = _dateRange;
    final dateLabel = dateRange == null
        ? null
        : _rangeLabel(context, dateRange);

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 18, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment: $paymentLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Date: $dateLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              16,
              6,
              16,
              16 + media.viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                Widget statusTile(_PaymentFilter value) {
                  final selected = _paymentFilter == value;
                  return RadioListTile<_PaymentFilter>(
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    groupValue: _paymentFilter,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _paymentFilter = v);
                      setModalState(() {});
                    },
                    title: Text(
                      _paymentLabel(value),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    secondary: Icon(
                      _statusIcon(value),
                      color: _statusColor(value),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Payment status',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    statusTile(_PaymentFilter.paid),
                    statusTile(_PaymentFilter.halfPaid),
                    statusTile(_PaymentFilter.unpaid),
                    const SizedBox(height: 10),

                    Text(
                      'Date',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _pickDateRange();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_rangeLabel(context, _dateRange)),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _clearFilters();
                            setModalState(() {});
                            unawaited(_refreshBackendHistory());
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(_refreshBackendHistory());
                          },
                          child: const Text('Apply'),
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

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

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

  Color _statusColor(_PaymentFilter filter) {
    switch (filter) {
      case _PaymentFilter.paid:
        return Colors.green;
      case _PaymentFilter.halfPaid:
        return Colors.orange;
      case _PaymentFilter.unpaid:
        return Colors.red;
    }
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
          title: const Text('Date'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<StockEntryProvider>();

    final baseEntries = widget.vendor == null
        ? provider.entries
        : provider.entries
              .where((e) => e.vendor.id == widget.vendor!.id)
              .toList(growable: false);

    final filteredEntries = _applyFilters(baseEntries);

    final subtitle = widget.vendor?.name ?? 'All traders';

    final hasAnyFilter =
        _dateRange != null || _paymentFilter != _PaymentFilter.unpaid;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final vendor = widget.vendor;
          if (vendor == null) return;
          await provider.refreshHistory(vendor: vendor);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              titleSpacing: 0,
              toolbarHeight: 78,
              title: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'History',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Clear filters',
                  onPressed: hasAnyFilter ? _clearFilters : null,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
                IconButton(
                  tooltip: 'Filters',
                  onPressed: _openFiltersSheet,
                  icon: const Icon(Icons.tune),
                ),
              ],
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: colorScheme.outlineVariant.withAlpha(120),
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 44,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          provider.error!,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            final vendor = widget.vendor;
                            if (vendor == null) return;
                            provider.refreshHistory(vendor: vendor);
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _filtersSummaryBar(context),
                ),
              ),
              if (baseEntries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withAlpha(180),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No transactions found',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing filters or date range',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (filteredEntries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withAlpha(180),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No transactions found',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing filters or date range',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: filteredEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _HistoryRow(
                        entry: entry,
                        money: _money,
                        showVendor: widget.vendor == null,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(StockEntryDetailScreen.route(entry: entry));
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.money,
    required this.showVendor,
    required this.onTap,
  });

  final StockEntry entry;
  final String Function(double) money;
  final bool showVendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceNo = entry.invoiceNumber?.trim();

    String ddMMyyyy(DateTime d) {
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      return '$dd/$mm/$yyyy';
    }

    final dateLabel = ddMMyyyy(entry.createdAt);

    final remaining = entry.payment.remainingAmount;
    final paid = entry.payment.paidAmount;
    final total = entry.payment.totalPayment;

    final bool isPaid = remaining <= 0;
    final bool isHalfPaid = !isPaid && paid > 0.0001;

    final String statusText = isPaid
        ? 'Paid'
        : (isHalfPaid ? 'Half Paid' : 'Unpaid');
    final Color statusColor = isPaid
        ? colorScheme.primary
        : (isHalfPaid ? colorScheme.tertiary : colorScheme.error);
    final IconData statusIcon = isPaid
        ? Icons.check_circle_outline_rounded
        : (isHalfPaid ? Icons.timelapse_outlined : Icons.warning_amber_rounded);

    final double due = remaining <= 0 ? 0 : remaining;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(90)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showVendor) ...[
                          Text(
                            entry.vendor.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (invoiceNo != null && invoiceNo.isNotEmpty) ...[
                          Text(
                            'Invoice #$invoiceNo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          dateLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    text: statusText,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                money(total),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Paid ${money(paid)}  •  Due ${money(due)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        'You’re all caught up',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
