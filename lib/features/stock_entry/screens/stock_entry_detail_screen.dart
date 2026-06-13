import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../billing/widgets/billing_ui.dart';
import '../models/stock_entry.dart';
import '../models/stock_entry_detail.dart';
import '../services/stock_entry_service.dart';
import '../widgets/stock_entry_ui.dart';

class StockEntryDetailScreen extends StatefulWidget {
  const StockEntryDetailScreen({super.key, required this.entry});

  static const String routeName = '/stock-entry/detail';

  static Route<void> route({required StockEntry entry}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockEntryDetailScreen(entry: entry),
    );
  }

  final StockEntry entry;

  @override
  State<StockEntryDetailScreen> createState() => _StockEntryDetailScreenState();
}

class _StockEntryDetailScreenState extends State<StockEntryDetailScreen> {
  late final Future<StockEntryDetail?> _detailsFuture;
  final Map<int, bool> _expandedProducts = <int, bool>{};

  @override
  void initState() {
    super.initState();
    final invoice = widget.entry.stknumber?.trim();
    if (invoice == null || invoice.isEmpty) {
      _detailsFuture = Future<StockEntryDetail?>.value(null);
    } else {
      _detailsFuture = StockEntryService().fetchStockEntryDetail(
        stknumber: invoice,
      );
    }
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

  (String, Color, IconData) _statusUi(StockEntryStatus status) {
    switch (status) {
      case StockEntryStatus.paid:
        return (
          'Paid',
          AppColors.emerald,
          Icons.check_circle_outline_rounded,
        );
      case StockEntryStatus.partial:
        return ('Half paid', AppColors.warning, Icons.timelapse_outlined);
      case StockEntryStatus.unpaid:
        return ('Unpaid', AppColors.error, Icons.warning_amber_rounded);
    }
  }

  Future<void> _copyInvoice(String invoice) async {
    await Clipboard.setData(ClipboardData(text: invoice));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Copied $invoice'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _invoiceRow(BuildContext context, String invoice) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: AppColors.emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  invoice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy invoice number',
            onPressed: () => _copyInvoice(invoice),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard({
    required BuildContext context,
    required double total,
    required double paid,
    required double pending,
    required String deadlineLabel,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          BillingSummaryLine(label: 'Total', value: _money(total)),
          BillingSummaryLine(label: 'Paid', value: _money(paid)),
          BillingSummaryLine(
            label: 'Pending',
            value: _money(pending),
            valueColor: pending > 0 ? AppColors.error : null,
          ),
          BillingSummaryLine(label: 'Deadline', value: deadlineLabel),
          if (pending > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            BillingSummaryLine(
              label: 'Amount due',
              value: _money(pending),
              bold: true,
              valueColor: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _variantRow(BuildContext context, StockEntryDetailVariant variant) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final size = variant.size.trim();
    final color = variant.color.trim();
    final meta = [
      if (size.isNotEmpty && size != '—') 'Size $size',
      if (color.isNotEmpty && color != '—') color,
      'Qty ${variant.quantity}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              meta,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            variant.actualPrice == null ? '—' : _money(variant.actualPrice!),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.emeraldDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(
    BuildContext context,
    int index,
    StockEntryDetailProduct product,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final company = product.companyName.trim();
    final gender = product.gender.trim();
    final meta = [
      if (company.isNotEmpty) company,
      if (gender.isNotEmpty) gender,
    ].join(' · ');

    final isExpanded = _expandedProducts[index] ?? false;
    final variants = product.variants;
    final visibleVariants =
        isExpanded ? variants : variants.take(3).toList(growable: false);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            product.productName.isEmpty ? 'Product' : product.productName,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...visibleVariants.map(
              (v) => Column(
                children: [
                  _variantRow(context, v),
                  if (v != visibleVariants.last)
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.slate200,
                    ),
                ],
              ),
            ),
            if (variants.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _expandedProducts[index] = !isExpanded;
                    });
                  },
                  child: Text(
                    isExpanded
                        ? 'Show less'
                        : 'Show ${variants.length - 3} more',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailBody(BuildContext context, StockEntryDetail details) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusText, statusColor, statusIcon) = _statusUi(details.status);
    final deadlineLabel = details.paymentDeadline == null
        ? '—'
        : _ddMMyyyy(details.paymentDeadline!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            StockEntryPaymentBadge(
              label: statusText,
              color: statusColor,
              icon: statusIcon,
            ),
            const Spacer(),
            Text(
              _ddMMyyyy(details.createdDate),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BillingPayableHero(
          label: 'Entry total',
          amount: _money(details.totalAmount),
          subtitle: details.vendorName,
        ),
        const SizedBox(height: 12),
        _invoiceRow(context, details.stknumber),
        const SizedBox(height: 12),
        _paymentCard(
          context: context,
          total: details.totalAmount,
          paid: details.paidAmount,
          pending: details.pendingAmount,
          deadlineLabel: deadlineLabel,
        ),
        const SizedBox(height: 20),
        Text(
          'Products (${details.products.length})',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...details.products.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _productCard(context, entry.key, entry.value),
          ),
        ),
      ],
    );
  }

  Widget _fallbackBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entry = widget.entry;

    final remaining = entry.payment.remainingAmount;
    final (statusText, statusColor, statusIcon) = remaining <= 0
        ? ('Paid', AppColors.emerald, Icons.check_circle_outline_rounded)
        : entry.payment.paidAmount > 0.0001
            ? ('Half paid', AppColors.warning, Icons.timelapse_outlined)
            : ('Unpaid', AppColors.error, Icons.warning_amber_rounded);

    final deadlineLabel = entry.payment.deadline == null
        ? '—'
        : _ddMMyyyy(entry.payment.deadline!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            StockEntryPaymentBadge(
              label: statusText,
              color: statusColor,
              icon: statusIcon,
            ),
            const Spacer(),
            Text(
              _ddMMyyyy(entry.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BillingPayableHero(
          label: 'Entry total',
          amount: _money(entry.payment.totalPayment),
          subtitle: entry.vendor.name,
        ),
        if (entry.stknumber != null && entry.stknumber!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _invoiceRow(context, entry.stknumber!.trim()),
        ],
        const SizedBox(height: 12),
        _paymentCard(
          context: context,
          total: entry.payment.totalPayment,
          paid: entry.payment.paidAmount,
          pending: entry.payment.remainingAmount,
          deadlineLabel: deadlineLabel,
        ),
        if (entry.items.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Items (${entry.items.length})',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...entry.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Qty ${item.quantity} · Cost ${_money(item.costPrice)} · Sell ${_money(item.sellingPrice)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(item.lineTotal),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invoice = widget.entry.stknumber?.trim();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text(
          invoice?.isNotEmpty == true ? 'Entry details' : 'Stock entry',
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<StockEntryDetail?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final details = snapshot.data;
          if (details == null) {
            return _fallbackBody(context);
          }

          return _detailBody(context, details);
        },
      ),
    );
  }
}
