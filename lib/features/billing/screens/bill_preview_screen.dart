import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';
import '../widgets/billing_ui.dart';

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

            final theme = Theme.of(dialogContext);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              title: Text(
                BillingService.whatsAppApiIntegrated
                    ? 'Send on WhatsApp?'
                    : 'Finish billing?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                BillingService.whatsAppApiIntegrated
                    ? 'Invoice will be sent to ${customer.phone} and billing will be completed.'
                    : 'Billing will be completed. WhatsApp sending will be enabled once the backend API is integrated.',
                style: theme.textTheme.bodyMedium,
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSending ? null : send,
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          BillingService.whatsAppApiIntegrated
                              ? 'Send & finish'
                              : 'Finish',
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
      BillingPaymentMethod.qr => 'QR',
      BillingPaymentMethod.card => 'Card',
      _ => '—',
    };
  }

  IconData _methodIcon(BillingPaymentMethod? method) {
    return switch (method) {
      BillingPaymentMethod.cash => Icons.payments_outlined,
      BillingPaymentMethod.qr => Icons.qr_code_2_rounded,
      BillingPaymentMethod.card => Icons.credit_card_outlined,
      _ => Icons.help_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;
    final itemCount = provider.items.length;
    final paymentLabel = _methodLabel(provider.paymentMethod);

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Review bill'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost done',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Review details, then finish billing',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BillingPayableHero(
            label: 'Bill total',
            amount: _money(provider.finalAmount),
            subtitle:
                '$itemCount item${itemCount == 1 ? '' : 's'} · Paid via $paymentLabel',
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
                    (customer?.name.trim().isNotEmpty == true
                            ? customer!.name.trim()[0]
                            : '?')
                        .toUpperCase(),
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
                        customer?.name.trim().isNotEmpty == true
                            ? customer!.name.trim()
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (customer?.phone.trim().isNotEmpty == true)
                        Text(
                          customer!.phone.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if ((customer?.address?.trim().isNotEmpty ?? false))
                        Text(
                          customer!.address!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                        _methodIcon(provider.paymentMethod),
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
          const SizedBox(height: 20),
          Text(
            'Items',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final item in provider.items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _productMeta(item),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
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
                  if (item != provider.items.last)
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.slate200,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                BillingSummaryLine(
                  label: 'Original total',
                  value: _money(provider.originalSubtotal),
                ),
                BillingSummaryLine(
                  label: 'Subtotal',
                  value: _money(provider.calculatedFinalAmount),
                ),
                if (provider.hasBillLevelSavings)
                  BillingSummaryLine(
                    label: 'Bill discount',
                    value: BillingProvider.formatDiscountSummary(
                      provider.billLevelSavings,
                      provider.billLevelSavingsPercent,
                    ),
                    valueColor: colorScheme.tertiary,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
                BillingSummaryLine(
                  label: 'Total payable',
                  value: _money(provider.finalAmount),
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.slate200,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money(provider.finalAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                      Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'} · $paymentLabel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _confirmAndSendWhatsApp(context),
                  icon: Icon(
                    BillingService.whatsAppApiIntegrated
                        ? Icons.send_rounded
                        : Icons.check_rounded,
                    size: 20,
                  ),
                  label: Text(
                    BillingService.whatsAppApiIntegrated
                        ? 'Send & finish'
                        : 'Finish bill',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _productMeta(BillingLineItem item) {
    final parts = <String>[
      'Qty ${item.quantity}',
      '${_money(item.unitPrice)} each',
    ];
    if (item.discountPercent > 0) {
      parts.add('${item.discountPercent.toStringAsFixed(0)}% off');
    } else if (item.isUnitPriceOverride &&
        (item.unitPrice - item.originalUnitPrice).abs() > 0.0001) {
      parts.add('was ${_money(item.originalUnitPrice)}');
    }
    return parts.join(' · ');
  }
}
