import 'package:flutter/material.dart';

import '../models/stock_entry.dart';

class StockEntryDetailScreen extends StatelessWidget {
  const StockEntryDetailScreen({super.key, required this.entry});

  static const String routeName = '/stock-entry/detail';

  static Route<void> route({required StockEntry entry}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockEntryDetailScreen(entry: entry),
    );
  }

  final StockEntry entry;

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final createdLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(entry.createdAt);

    final deadlineLabel = entry.payment.deadline == null
        ? '—'
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(entry.payment.deadline!);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Entry Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.vendor.name,
                    style: theme.textTheme.titleLarge?.copyWith(
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
      ),
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
