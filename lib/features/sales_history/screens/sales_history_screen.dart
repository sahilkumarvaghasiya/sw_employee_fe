import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../billing/models/billing_models.dart';
import '../../billing/widgets/billing_ui.dart';
import '../models/sales_bill.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/sales_history_ui.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _maxTotalController = TextEditingController();
  Timer? _searchDebounce;
  static final NumberFormat _inrFormat = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SalesHistoryProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _maxTotalController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<SalesHistoryProvider>().updateSearchQuery(value);
    });
  }

  String _money(double value) => '₹${_inrFormat.format(value)}';

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

  Future<void> _applyCurrentFilters() async {
    await context.read<SalesHistoryProvider>().applyFilters(
      dateRange: _dateRange,
      maxTotal: _parseMaxTotal(),
    );
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
        String fmt(DateTime? d) => d == null ? 'Not set' : _ddMMyyyy(d);

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
      await _applyCurrentFilters();
      return;
    }

    if (picked is _DateRangeApplied) {
      setState(() => _dateRange = picked.range);
      await _applyCurrentFilters();
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _dateRange = null;
      _searchController.clear();
      _maxTotalController.clear();
    });
    await context.read<SalesHistoryProvider>().applyQueryFilters(
      dateRange: null,
      maxTotal: null,
      searchQuery: '',
    );
  }

  int _activeFilterCount() {
    var count = 0;
    if (_dateRange != null) count++;
    if (_maxTotalController.text.trim().isNotEmpty) count++;
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
                      'Filter bills',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date range and maximum bill total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                          _dateLabel(context, _dateRange),
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
                    const SizedBox(height: 16),
                    Text(
                      'Max bill total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxTotalController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '≤ ₹ ',
                        hintText: 'Any amount',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          borderSide:
                              BorderSide(color: colorScheme.outlineVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _clearFilters();
                            setModalState(() {});
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            await _applyCurrentFilters();
                            if (context.mounted) Navigator.of(context).pop();
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

  String _methodLabel(BillingPaymentMethod method) {
    switch (method) {
      case BillingPaymentMethod.cash:
        return 'Cash';
      case BillingPaymentMethod.qr:
        return 'QR Barcode';
      case BillingPaymentMethod.card:
        return 'Card';
    }
  }

  Future<void> _openBillDetails(SalesBill bill) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    rootNavigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black38,
        barrierDismissible: false,
        pageBuilder: (_, _, _) =>
            const Center(child: CircularProgressIndicator()),
      ),
    );

    SalesBill details;
    try {
      details = await context.read<SalesHistoryProvider>().fetchBillDetails(
        bill.id,
      );
    } catch (_) {
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load bill details')),
      );
      return;
    }

    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BillDetailsSheet(
        bill: details,
        money: _money,
        methodLabel: _methodLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<SalesHistoryProvider>();
    final bills = provider.bills;
    final filterCount = _activeFilterCount();

    final hasAnyFilter =
        _dateRange != null ||
        _maxTotalController.text.trim().isNotEmpty ||
        _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Sales history'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (hasAnyFilter)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear all'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        color: AppColors.emerald,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Past bills and invoices',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SalesHistorySearchBar(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SalesHistoryFilterButton(
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
                            if (_searchController.text.trim().isNotEmpty)
                              SalesHistoryActiveFilterChip(
                                label:
                                    'Search: ${_searchController.text.trim()}',
                                onRemove: () {
                                  setState(_searchController.clear);
                                  _onSearchChanged('');
                                },
                              ),
                            if (_dateRange != null) ...[
                              if (_searchController.text.trim().isNotEmpty)
                                const SizedBox(width: 6),
                              SalesHistoryActiveFilterChip(
                                label: _dateLabel(context, _dateRange),
                                onRemove: () async {
                                  setState(() => _dateRange = null);
                                  await _applyCurrentFilters();
                                },
                              ),
                            ],
                            if (_maxTotalController.text.trim().isNotEmpty) ...[
                              if (_searchController.text.trim().isNotEmpty ||
                                  _dateRange != null)
                                const SizedBox(width: 6),
                              SalesHistoryActiveFilterChip(
                                label:
                                    '≤ ₹${_maxTotalController.text.trim()}',
                                onRemove: () async {
                                  setState(_maxTotalController.clear);
                                  await _applyCurrentFilters();
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
            if (!provider.isLoading && provider.error == null && bills.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    '${bills.length} bill${bills.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (provider.isLoading && bills.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && bills.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: SalesHistoryEmptyState(
                  title: 'Could not load sales history',
                  subtitle: provider.error,
                  actionLabel: 'Try again',
                  onAction: provider.refresh,
                  icon: Icons.cloud_off_outlined,
                ),
              )
            else if (bills.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: SalesHistoryEmptyState(
                  title: 'No bills found',
                  subtitle: hasAnyFilter
                      ? 'Try adjusting your search or filters'
                      : 'Completed sales will appear here',
                  actionLabel: hasAnyFilter ? 'Clear filters' : null,
                  onAction: hasAnyFilter ? _clearFilters : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverList.separated(
                  itemCount: bills.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    final loc = MaterialLocalizations.of(context);
                    final date = loc.formatShortDate(bill.createdAt);
                    final time = loc.formatTimeOfDay(
                      TimeOfDay.fromDateTime(bill.createdAt),
                      alwaysUse24HourFormat: false,
                    );

                    return SalesHistoryBillTile(
                      billNo: bill.billNo,
                      customerName: bill.customer.name,
                      customerPhone: bill.customer.phone,
                      dateLabel: date,
                      timeLabel: time,
                      amountLabel: bill.listAmount != null
                          ? _money(bill.listAmount!)
                          : null,
                      onTap: () => _openBillDetails(bill),
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

  IconData _methodIcon(BillingPaymentMethod method) {
    return switch (method) {
      BillingPaymentMethod.cash => Icons.payments_outlined,
      BillingPaymentMethod.qr => Icons.qr_code_2_rounded,
      BillingPaymentMethod.card => Icons.credit_card_outlined,
    };
  }

  String _itemMeta(SalesLineItem item) {
    final parts = <String>[
      'Qty ${item.quantity}',
      '${money(item.unitPrice)} each',
    ];
    if ((item.enteredDiscountPercent ?? 0) > 0) {
      parts.add('${item.enteredDiscountPercent!.toStringAsFixed(0)}% off');
    } else if (item.discountAmount > 0) {
      parts.add('${money(item.discountAmount)} off');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final loc = MaterialLocalizations.of(context);
    final date = loc.formatShortDate(bill.createdAt);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(bill.createdAt));
    final itemCount = bill.itemsCount;
    final paymentLabel = methodLabel(bill.paymentMethod);

    return SafeArea(
      child: SizedBox(
        height: screenHeight * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bill details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bill.billNo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              BillingPayableHero(
                label: 'Bill total',
                amount: money(bill.total),
                subtitle: '$itemCount item${itemCount == 1 ? '' : 's'} · $paymentLabel',
              ),
              const SizedBox(height: 12),
              AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.emerald.withValues(alpha: 0.12),
                      child: Text(
                        bill.customer.name.trim().isNotEmpty
                            ? bill.customer.name.trim()[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            bill.customer.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$date · $time',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _methodIcon(bill.paymentMethod),
                            size: 14,
                            color: AppColors.emeraldDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    BillingSummaryLine(
                      label: 'Subtotal',
                      value: money(bill.subtotal),
                    ),
                    if (bill.totalDiscount > 0.0001)
                      BillingSummaryLine(
                        label: 'Discount',
                        value: '- ${money(bill.totalDiscount)}',
                        valueColor: colorScheme.tertiary,
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1),
                    ),
                    BillingSummaryLine(
                      label: 'Total',
                      value: money(bill.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Items',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: bill.items.isEmpty
                    ? Center(
                        child: Text(
                          'No line items in response',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: bill.items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.slate200,
                        ),
                        itemBuilder: (context, index) {
                          final item = bill.items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _itemMeta(item),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  money(item.lineTotal),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emeraldDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
