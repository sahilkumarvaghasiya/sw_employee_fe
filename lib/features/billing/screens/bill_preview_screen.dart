import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class BillPreviewScreen extends StatelessWidget {
  const BillPreviewScreen({super.key});

  static Route<void> route(BuildContext context) {
    final provider = context.read<BillingProvider>();
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/preview'),
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const BillPreviewScreen(),
        );
      },
    );
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _methodLabel(BillingPaymentMethod? method) {
    return switch (method) {
      BillingPaymentMethod.cash => 'Cash',
      BillingPaymentMethod.upi => 'UPI',
      BillingPaymentMethod.paytm => 'Paytm',
      _ => '—',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill confirmation')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Customer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Name', value: customer?.name ?? '—'),
                  _InfoRow(label: 'Phone', value: customer?.phone ?? '—'),
                  _InfoRow(label: 'Address', value: customer?.address ?? '—'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Products',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                for (final item in provider.items) ...[
                  ListTile(
                    title: Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Qty ${item.quantity} • Price ${_money(item.unitPrice)} • Disc ${item.discountPercent.toStringAsFixed(0)}%',
                    ),
                    trailing: Text(
                      _money(item.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (item != provider.items.last) const Divider(height: 0),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Total items',
                    value: provider.totalItems.toString(),
                  ),
                  _InfoRow(label: 'Subtotal', value: _money(provider.subtotal)),
                  _InfoRow(
                    label: 'Discount',
                    value: _money(provider.totalDiscount),
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    label: 'Final amount',
                    value: _money(provider.finalAmount),
                    valueWeight: FontWeight.w900,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Payment method',
                    value: _methodLabel(provider.paymentMethod),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    _showSnack(context, 'Send via WhatsApp (simulated)');
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Send via WhatsApp'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<BillingProvider>().clearAll();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueWeight});

  final String label;
  final String value;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: valueWeight ?? FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
