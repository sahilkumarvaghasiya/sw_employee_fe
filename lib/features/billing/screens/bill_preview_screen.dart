import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';

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

  Future<void> _confirmAndSendWhatsApp(BuildContext context) async {
    final provider = context.read<BillingProvider>();
    final customer = provider.customer;
    if (customer == null) {
      _showSnack(context, 'Customer details are missing');
      return;
    }
    if (provider.items.isEmpty) {
      _showSnack(context, 'No products in the bill');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> send() async {
              if (isSending) return;
              setState(() => isSending = true);

              try {
                final paymentMethod = provider.paymentMethod;
                if (paymentMethod == null) {
                  throw Exception('Please select a payment method.');
                }

                final billResult = await BillingService().createSalesBill(
                  customer: customer,
                  items: provider.items,
                  paymentMethod: paymentMethod,
                  markPaid: provider.markPaid,
                  finalAmount: provider.finalAmount,
                  calculatedFinalAmount: provider.calculatedFinalAmount,
                );

                if (context.mounted) {
                  final number = billResult.billNumber.trim();
                  _showSnack(
                    context,
                    number.isEmpty
                        ? billResult.message
                        : 'Bill created: $number',
                  );
                }

                await BillingService().sendWhatsAppInvoice(
                  customer: customer,
                  items: provider.items,
                  paymentMethod: paymentMethod,
                  markPaid: provider.markPaid,
                  paidAmount: provider.paidAmount,
                  subtotal: provider.subtotal,
                  totalDiscount: provider.totalDiscount,
                  finalAmount: provider.finalAmount,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnack(context, e.toString());
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Send bill on WhatsApp?'),
              content: Text(
                BillingService.whatsAppApiIntegrated
                    ? 'This will send the invoice to ${customer.phone} and finish billing.'
                    : 'This will finish billing. WhatsApp sending will be enabled once the backend API is integrated.',
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSending ? null : send,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            BillingService.whatsAppApiIntegrated
                                ? 'Send & Done'
                                : 'Done',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      provider.clearAll();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _methodLabel(BillingPaymentMethod? method) {
    return switch (method) {
      BillingPaymentMethod.cash => 'Cash',
      BillingPaymentMethod.qr => 'QR Barcode',
      BillingPaymentMethod.upi => 'UPI',
      BillingPaymentMethod.paytm => 'Paytm',
      BillingPaymentMethod.card => 'Card',
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmAndSendWhatsApp(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Done'),
              ),
            ),
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
