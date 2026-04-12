import 'package:flutter/material.dart';

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

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice #${details.invoiceNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  details.vendorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _ddMMyyyy(details.createdDate),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _statusBadge(
                            statusText,
                            statusColor,
                            statusIcon,
                            theme.textTheme,
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

              ...details.products.map((p) {
                final subtitleParts = <String>[];
                if (p.companyName.trim().isNotEmpty) {
                  subtitleParts.add(p.companyName.trim());
                }
                if (p.gender.trim().isNotEmpty) {
                  subtitleParts.add(p.gender.trim());
                }
                final subtitle = subtitleParts.join(' • ');

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
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          ...p.variants.map((v) {
                            final leftParts = <String>[];
                            if (v.size.trim().isNotEmpty) {
                              leftParts.add('Size ${v.size.trim()}');
                            }
                            if (v.color.trim().isNotEmpty) {
                              leftParts.add(v.color.trim());
                            }
                            if (v.actualPrice != null) {
                              leftParts.add('Price ${_money(v.actualPrice!)}');
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      leftParts.join(' • '),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Qty ${v.quantity}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
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
                  Text(
                    'Invoice #${entry.invoiceNumber!.trim()}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  entry.vendor.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
