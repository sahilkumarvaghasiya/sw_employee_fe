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
                  selectedQrConfigId: provider.selectedQrConfig?.id,
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
      appBar: AppBar(
        title: const Text('Bill confirmation'),
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Final payable',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _money(provider.finalAmount),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  label: Text(
                    _methodLabel(provider.paymentMethod),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Customer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Products (${provider.items.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final item in provider.items) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _ProductStatChip(
                                      label: 'Qty',
                                      value: item.quantity.toString(),
                                    ),
                                    _ProductStatChip(
                                      label: 'Unit',
                                      value: _money(item.unitPrice),
                                    ),
                                    if (item.discountPercent > 0)
                                      _ProductStatChip(
                                        label: 'Disc',
                                        value:
                                            '${item.discountPercent.toStringAsFixed(0)}%',
                                      )
                                    else if (item.isUnitPriceOverride &&
                                        (item.unitPrice -
                                                    item.originalUnitPrice)
                                                .abs() >
                                            0.0001)
                                      _ProductStatChip(
                                        label: 'Original',
                                        value: _money(item.originalUnitPrice),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _money(item.lineTotal),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item != provider.items.last)
                      Divider(height: 1, color: colorScheme.outlineVariant),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Totals',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Original total',
                    value: _money(provider.originalSubtotal),
                  ),
                  _InfoRow(
                    label: 'Subtotal',
                    value: _money(provider.calculatedFinalAmount),
                  ),
                  if (provider.hasBillLevelSavings)
                    _InfoRow(
                      label: 'Discount',
                      value: BillingProvider.formatDiscountSummary(
                        provider.billLevelSavings,
                        provider.billLevelSavingsPercent,
                      ),
                      valueColor: colorScheme.tertiary,
                    ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _InfoRow(
                      label: 'Total',
                      value: _money(provider.finalAmount),
                      valueWeight: FontWeight.w900,
                    ),
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
          child: FilledButton.icon(
            onPressed: () => _confirmAndSendWhatsApp(context),
            icon: const Icon(Icons.check_circle_outline),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                BillingService.whatsAppApiIntegrated ? 'Send & Finish' : 'Done',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueWeight,
    this.valueColor,
  });

  final String label;
  final String value;
  final FontWeight? valueWeight;
  final Color? valueColor;

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
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductStatChip extends StatelessWidget {
  const _ProductStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
