import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../billing/models/billing_models.dart';
import '../models/sales_bill.dart';
import '../providers/sales_history_provider.dart';

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

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  static const String routeName = '/sales/history';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => SalesHistoryProvider(),
        child: const SalesHistoryScreen(),
      ),
    );
  }

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTimeRange? _dateRange;
  final TextEditingController _maxTotalController = TextEditingController();

  @override
  void dispose() {
    _maxTotalController.dispose();
    super.dispose();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _dateLabel(BuildContext context, DateTimeRange? range) {
    if (range == null) return 'Select date range';
    return '${_ddMMyyyy(range.start)} – ${_ddMMyyyy(range.end)}';
  }

  double? _parseMaxTotal() {
    final raw = _maxTotalController.text.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(',', '');
    return double.tryParse(normalized);
  }

  List<SalesBill> _applyFilters(List<SalesBill> bills) {
    final maxTotal = _parseMaxTotal();
    final range = _dateRange;
    if (range == null && maxTotal == null) return bills;

    final start = range?.start;
    final endExclusive = range == null
        ? null
        : DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1));

    return bills.where((b) {
      if (start != null && b.createdAt.isBefore(start)) return false;
      if (endExclusive != null && !b.createdAt.isBefore(endExclusive)) {
        return false;
      }
      if (maxTotal != null && b.total > maxTotal) return false;
      return true;
    }).toList();
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

    if (start == null || end == null) {
      start = clamp(now.subtract(const Duration(days: 7)));
      end = clamp(now);
    }

    if (end.isBefore(start)) {
      end = start;
    }

    final picked = await showDialog<_DateRangeDialogResult?>(
      context: context,
      builder: (dialogContext) {
        String fmt(DateTime d) => _ddMMyyyy(d);

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
                subtitle: Text(fmt(start!)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('End date'),
                subtitle: Text(fmt(end!)),
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
              onPressed: () =>
                  Navigator.of(dialogContext).pop(const _DateRangeCleared()),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
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

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _maxTotalController.clear();
    });
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
        final isWide = media.size.width >= 520;

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
                final dateField = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_dateLabel(context, _dateRange)),
                  ),
                  onPressed: () async {
                    await _pickDateRange();
                    setModalState(() {});
                  },
                );

                final maxField = TextField(
                  controller: _maxTotalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee_outlined),
                    labelText: 'Max total (≤)',
                    suffixIcon: _maxTotalController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              setState(_maxTotalController.clear);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    setModalState(() {});
                  },
                );

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
                              fontWeight: FontWeight.w900,
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
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: dateField),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(height: 56, child: maxField),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dateField,
                          const SizedBox(height: 12),
                          SizedBox(height: 56, child: maxField),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _clearFilters();
                            setModalState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
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

  String _methodLabel(BillingPaymentMethod method) {
    switch (method) {
      case BillingPaymentMethod.cash:
        return 'Cash';
      case BillingPaymentMethod.qr:
        return 'QR Barcode';
      case BillingPaymentMethod.paytm:
        return 'Paytm';
      case BillingPaymentMethod.upi:
        return 'UPI';
      case BillingPaymentMethod.card:
        return 'Card';
    }
  }

  Future<void> _openBillDetails(SalesBill bill) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BillDetailsSheet(
        bill: bill,
        money: _money,
        methodLabel: _methodLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<SalesHistoryProvider>();
    final filtered = _applyFilters(provider.bills);

    final hasAnyFilter =
        _dateRange != null || _maxTotalController.text.trim().isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              titleSpacing: 0,
              toolbarHeight: 78,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              title: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sales history',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a bill to view details',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: colorScheme.outlineVariant.withAlpha(120),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.date_range_outlined),
                      label: Text(_dateLabel(context, _dateRange)),
                      onPressed: _pickDateRange,
                    ),
                    if (_maxTotalController.text.trim().isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.currency_rupee_outlined),
                        label: Text('≤ ₹${_maxTotalController.text.trim()}'),
                        onPressed: _openFiltersSheet,
                      ),
                  ],
                ),
              ),
            ),
            if (provider.bills.isEmpty)
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
                          'No bills found',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
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
                          'No bills match your filters',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try changing date range or max total.',
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
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bill = filtered[index];
                    final loc = MaterialLocalizations.of(context);
                    final date = loc.formatShortDate(bill.createdAt);
                    final time = loc.formatTimeOfDay(
                      TimeOfDay.fromDateTime(bill.createdAt),
                      alwaysUse24HourFormat: false,
                    );

                    return Material(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openBillDetails(bill),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withAlpha(18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bill #${bill.billNo}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${bill.customer.name} • ${bill.customer.phone}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$date • $time • ${bill.itemsCount} items • ${_methodLabel(bill.paymentMethod)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _money(bill.total),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      ),
    );
  }
}

class _BillDetailsSheet extends StatelessWidget {
  const _BillDetailsSheet({
    required this.bill,
    required this.money,
    required this.methodLabel,
  });

  final SalesBill bill;
  final String Function(double) money;
  final String Function(BillingPaymentMethod) methodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final loc = MaterialLocalizations.of(context);
    final date = loc.formatShortDate(bill.createdAt);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(bill.createdAt));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill #${bill.billNo}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bill.customer.name} • ${bill.customer.phone}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$date • $time • ${methodLabel(bill.paymentMethod)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Subtotal', value: money(bill.subtotal)),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Discount',
                      value: '- ${money(bill.totalDiscount)}',
                      muted: true,
                    ),
                    const Divider(height: 16),
                    _SummaryRow(
                      label: 'Total',
                      value: money(bill.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Items',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bill.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = bill.items[index];
                  return Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity} × ${money(item.unitPrice)}'
                                  '${item.discountPercent > 0 ? ' • ${item.discountPercent.toStringAsFixed(0)}% off' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            money(item.lineTotal),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final valueStyle =
        (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
            ?.copyWith(fontWeight: bold ? FontWeight.w900 : FontWeight.w700);

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: muted
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
