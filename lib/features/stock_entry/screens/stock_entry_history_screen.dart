import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import 'stock_entry_detail_screen.dart';

enum _PaymentFilter { paid, halfPaid, unpaid }

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

  _PaymentFilter _paymentFilter = _PaymentFilter.unpaid;
  DateTimeRange? _dateRange;

  bool _showInlineDatePicker = false;
  DateTime? _draftRangeStart;
  DateTime? _draftRangeEnd;

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

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
    // Intentionally left as a no-op: date picking is inline.
    // Kept to avoid breaking any older call-sites.
    return;
  }

  void _toggleInlineDatePicker() {
    final now = DateTime.now();
    final current = _dateRange;

    setState(() {
      _showInlineDatePicker = !_showInlineDatePicker;
      if (_showInlineDatePicker) {
        _draftRangeStart =
            current?.start ?? now.subtract(const Duration(days: 7));
        _draftRangeEnd = current?.end;
      }
    });
  }

  void _onInlineDatePicked(DateTime day) {
    setState(() {
      final start = _draftRangeStart;
      final end = _draftRangeEnd;

      if (start == null || (start != null && end != null)) {
        _draftRangeStart = day;
        _draftRangeEnd = null;
        return;
      }

      _draftRangeEnd = day;

      final s = _draftRangeStart!;
      final e = _draftRangeEnd!;
      final startFinal = e.isBefore(s) ? e : s;
      final endFinal = e.isBefore(s) ? s : e;

      _dateRange = DateTimeRange(start: startFinal, end: endFinal);
      _showInlineDatePicker = false;
    });
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

    final title = widget.vendor == null
        ? 'Stock Entry History'
        : 'History • ${widget.vendor!.name}';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.refreshHistory,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              titleSpacing: 0,
              title: Text(title),
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
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
                          onPressed: provider.refreshHistory,
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Builder(
                            builder: (context) {
                              String dateLabel() {
                                final range = _dateRange;
                                if (range == null) return 'Any date';
                                final loc = MaterialLocalizations.of(context);
                                final start = loc.formatShortDate(range.start);
                                final end = loc.formatShortDate(range.end);
                                return '$start–$end';
                              }

                              final segmented = SegmentedButton<_PaymentFilter>(
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  side: WidgetStatePropertyAll(
                                    BorderSide(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                segments: const [
                                  ButtonSegment<_PaymentFilter>(
                                    value: _PaymentFilter.paid,
                                    label: Text('Paid'),
                                  ),
                                  ButtonSegment<_PaymentFilter>(
                                    value: _PaymentFilter.halfPaid,
                                    label: Text('Half'),
                                  ),
                                  ButtonSegment<_PaymentFilter>(
                                    value: _PaymentFilter.unpaid,
                                    label: Text('Unpaid'),
                                  ),
                                ],
                                selected: <_PaymentFilter>{_paymentFilter},
                                onSelectionChanged: (value) {
                                  setState(() {
                                    _paymentFilter = value.first;
                                  });
                                },
                              );

                              final dateButton = FilledButton.tonalIcon(
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity(
                                    horizontal: -2,
                                    vertical: -2,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _toggleInlineDatePicker,
                                icon: const Icon(Icons.date_range_outlined),
                                label: Text(dateLabel()),
                              );

                              final clearButton = _dateRange == null
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      tooltip: 'Clear date',
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => setState(() {
                                        _dateRange = null;
                                        _draftRangeStart = null;
                                        _draftRangeEnd = null;
                                        _showInlineDatePicker = false;
                                      }),
                                      icon: const Icon(Icons.close_rounded),
                                    );

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool narrow =
                                      constraints.maxWidth < 520;

                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.tune_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: segmented),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(child: dateButton),
                                            if (_dateRange != null) ...[
                                              const SizedBox(width: 6),
                                              clearButton,
                                            ],
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      const Icon(Icons.tune_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: segmented),
                                      const SizedBox(width: 10),
                                      dateButton,
                                      if (_dateRange != null) ...[
                                        const SizedBox(width: 6),
                                        clearButton,
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_showInlineDatePicker)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (() {
                                      final start = _draftRangeStart;
                                      final end = _draftRangeEnd;
                                      if (start == null || end != null) {
                                        return 'Pick start date';
                                      }
                                      return 'Pick end date';
                                    })(),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(() {
                                    _showInlineDatePicker = false;
                                  }),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CalendarDatePicker(
                              initialDate:
                                  _draftRangeEnd ??
                                  _draftRangeStart ??
                                  DateTime.now(),
                              firstDate: DateTime(DateTime.now().year - 2),
                              lastDate: DateTime(DateTime.now().year + 1),
                              onDateChanged: _onInlineDatePicked,
                            ),
                          ],
                        ),
                      ),
                    ),
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
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.vendor == null
                                ? 'No stock entries yet'
                                : 'No stock entries for this vendor yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'New entries will appear here as soon as you save a stock entry.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                            Icons.filter_alt_off_outlined,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No entries match your filter',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different payment status or clear the date range.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  sliver: SliverList.separated(
                    itemCount: filteredEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _HistoryRow(
                        entry: entry,
                        money: _money,
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
    required this.onTap,
  });

  final StockEntry entry;
  final String Function(double) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(entry.createdAt);

    final remaining = entry.payment.remainingAmount;
    final paid = entry.payment.paidAmount;
    final total = entry.payment.totalPayment;

    final bool isPaid = remaining <= 0;
    final bool isHalfPaid = !isPaid && paid > 0.0001;

    final String statusText = isPaid
        ? 'Paid'
        : (isHalfPaid ? 'Half paid' : 'Unpaid');

    final Color statusColor = isPaid
        ? colorScheme.tertiary
        : (isHalfPaid ? colorScheme.primary : colorScheme.error);

    final double due = remaining <= 0 ? 0 : remaining;

    return Card(
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withAlpha(90)),
                    ),
                    child: Icon(
                      isPaid
                          ? Icons.check_circle_outline
                          : (isHalfPaid
                                ? Icons.timelapse_outlined
                                : Icons.warning_amber_outlined),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.vendor.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateLabel • ${entry.items.length} item${entry.items.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withAlpha(90)),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: colorScheme.outlineVariant.withAlpha(120),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AmountPill(
                      label: 'Total',
                      value: money(total),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AmountPill(
                      label: 'Paid',
                      value: money(paid),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AmountPill(
                      label: 'Due',
                      value: money(due),
                      icon: Icons.account_balance_wallet_outlined,
                      emphasisColor: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasisColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? emphasisColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = emphasisColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent ?? colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent ?? colorScheme.onSurface,
                  ),
                ),
              ],
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
