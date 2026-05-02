import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/stock_entry.dart';
import '../models/stock_entry_detail.dart';
import '../services/stock_entry_service.dart';

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
    final invoice = widget.entry.invoiceNumber?.trim();
    if (invoice == null || invoice.isEmpty) {
      _detailsFuture = Future<StockEntryDetail?>.value(null);
    } else {
      _detailsFuture = StockEntryService().fetchStockEntryDetail(
        invoiceNumber: invoice,
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

  (String, Color, IconData) _statusUi(StockEntryStatus status, ColorScheme cs) {
    switch (status) {
      case StockEntryStatus.paid:
        return ('Paid', Colors.green, Icons.check_circle_outline_rounded);
      case StockEntryStatus.partial:
        return ('Partial', Colors.orange, Icons.timelapse_outlined);
      case StockEntryStatus.unpaid:
        return ('Unpaid', Colors.red, Icons.warning_amber_rounded);
    }
  }

  Widget _statusBadge(String text, Color color, IconData icon, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: tt.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceToast(String invoice) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Invoice: $invoice',
            softWrap: true,
            maxLines: 3,
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showCopyToast(String invoice) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Copied $invoice',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: false,
          action: null,
          dismissDirection: DismissDirection.none,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Entry Details')),
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

          final (statusText, statusColor, statusIcon) = _statusUi(
            details.status,
            colorScheme,
          );

          final deadlineLabel = details.paymentDeadline == null
              ? '—'
              : _ddMMyyyy(details.paymentDeadline!);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                elevation: 1,
                color: colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withAlpha(110),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          6,
                                        ),
                                        onTap: () => _showInvoiceToast(
                                          details.invoiceNumber,
                                        ),
                                        child: Text(
                                          details.invoiceNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy invoice number',
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(
                                            text: details.invoiceNumber,
                                          ),
                                        );
                                        if (!mounted) return;
                                        _showCopyToast(details.invoiceNumber);
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _statusBadge(
                                statusText,
                                statusColor,
                                statusIcon,
                                theme.textTheme,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text(
                                  'Vendor:',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  details.vendorName,
                                  softWrap: true,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text(
                                  'Created:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _ddMMyyyy(details.createdDate),
                                  softWrap: true,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Payment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    children: [
                      _KeyValueRow(
                        label: 'Total amount',
                        value: _money(details.totalAmount),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(
                        label: 'Paid amount',
                        value: _money(details.paidAmount),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(
                        label: 'Pending amount',
                        value: _money(details.pendingAmount),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(
                        label: 'Payment deadline',
                        value: deadlineLabel,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Products',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),

              ...details.products.asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                final company = p.companyName.trim();
                final gender = p.gender.trim();
                final isExpanded = _expandedProducts[index] ?? false;
                final variants = p.variants;
                final visibleVariants =
                    isExpanded ? variants : variants.take(2).toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            p.productName.isEmpty ? 'Product' : p.productName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (company.isNotEmpty || gender.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            if (company.isNotEmpty)
                              Text(
                                'Brand: $company',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (gender.isNotEmpty)
                              Text(
                                'Gender: $gender',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                          const SizedBox(height: 10),
                          // White rounded inner box containing a table-like layout
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withOpacity(0.9),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Table(
                                // NEW
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FlexColumnWidth(2.5),
                                  2: FlexColumnWidth(1.5),
                                  3: FlexColumnWidth(2),
                                },
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  // Header row
                                  TableRow(
                                    children: [
                                      // Header cells with bottom border
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: colorScheme.outlineVariant
                                                  .withOpacity(0.7),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Size',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: colorScheme.outlineVariant
                                                  .withOpacity(0.7),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Color',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: colorScheme.outlineVariant
                                                  .withOpacity(0.7),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Qty',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: colorScheme.outlineVariant
                                                  .withOpacity(0.7),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Price',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Data rows
                                  ...visibleVariants.map((v) {
                                    final size = v.size.trim();
                                    final color = v.color.trim();
                                    final price = v.actualPrice;
                                    return TableRow(
                                      decoration: const BoxDecoration(),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth:
                                                            constraints.maxWidth),
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      physics:
                                                          const BouncingScrollPhysics(),
                                                      child: Text(
                                                        size.isEmpty ? '—' : size,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth:
                                                            constraints.maxWidth),
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      physics:
                                                          const BouncingScrollPhysics(),
                                                      child: Text(
                                                        color.isEmpty ? '—' : color,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: Text(
                                              v.quantity.toString(),
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth:
                                                            constraints.maxWidth),
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      physics:
                                                          const BouncingScrollPhysics(),
                                                      child: Text(
                                                        price == null
                                                            ? '—'
                                                            : _money(price),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          if (variants.length > 2)
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
                                      : 'Show more',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _fallbackBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final entry = widget.entry;
    final createdLabel = _ddMMyyyy(entry.createdAt);

    final deadlineLabel = entry.payment.deadline == null
        ? '—'
        : _ddMMyyyy(entry.payment.deadline!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entry.invoiceNumber != null &&
                    entry.invoiceNumber!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _showInvoiceToast(
                            entry.invoiceNumber!.trim(),
                          ),
                          child: Text(
                            entry.invoiceNumber!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy invoice number',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: entry.invoiceNumber!.trim(),
                            ),
                          );
                          if (!mounted) return;
                          _showCopyToast(entry.invoiceNumber!.trim());
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Vendor:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.vendor.name,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Created:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        createdLabel,
                        softWrap: true,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Products',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        ...entry.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                title: Text(
                  item.productName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Qty: ${item.quantity} • Cost: ${_money(item.costPrice)} • Sell: ${_money(item.sellingPrice)}',
                ),
                trailing: Text(
                  _money(item.lineTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 6),

        Text(
          'Payment',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                _KeyValueRow(
                  label: 'Total payment',
                  value: _money(entry.payment.totalPayment),
                ),
                const SizedBox(height: 10),
                _KeyValueRow(
                  label: 'Paid amount',
                  value: _money(entry.payment.paidAmount),
                ),
                const SizedBox(height: 10),
                _KeyValueRow(
                  label: 'Due amount',
                  value: _money(entry.payment.remainingAmount),
                ),
                const SizedBox(height: 10),
                _KeyValueRow(label: 'Deadline date', value: deadlineLabel),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
