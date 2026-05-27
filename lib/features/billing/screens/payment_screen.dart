import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';
import 'bill_preview_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  static Route<void> route(BuildContext context) {
    final provider = context.read<BillingProvider>();
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/payment'),
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const PaymentScreen(),
        );
      },
    );
  }

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _paidController = TextEditingController();
  final BillingService _billingService = BillingService();

  late final Future<List<BillingQrConfig>> _qrConfigsFuture;

  @override
  void initState() {
    super.initState();
    _qrConfigsFuture = _billingService.fetchQrPaymentConfigs();
    final provider = context.read<BillingProvider>();
    _paidController.text = provider.paidAmount == 0
        ? ''
        : provider.paidAmount.toStringAsFixed(2);

    _paidController.addListener(() {
      final raw = _paidController.text.trim();
      final value = raw.isEmpty ? 0.0 : (double.tryParse(raw) ?? 0.0);
      context.read<BillingProvider>().setPaidAmount(value);
    });
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  Future<void> _showQrSelectionSheet() async {
    final provider = context.read<BillingProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FutureBuilder<List<BillingQrConfig>>(
                    future: _qrConfigsFuture,
                    builder: (context, snapshot) {
                      final selectedQr = provider.selectedQrConfig;
                      final qrConfigs =
                          snapshot.data ?? const <BillingQrConfig>[];
                      final canContinue = selectedQr != null;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'QR barcode payment',
                                  style: theme.textTheme.titleMedium?.copyWith(
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
                          Text(
                            'Select a QR from dashboard and show it to the customer.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (snapshot.hasError)
                            Card(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text('Could not load QR codes.'),
                              ),
                            )
                          else if (qrConfigs.isEmpty)
                            Card(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text('No QR barcode available.'),
                              ),
                            )
                          else ...[
                            Text(
                              'Choose barcode',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: qrConfigs.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1,
                                  ),
                              itemBuilder: (context, index) {
                                final qr = qrConfigs[index];
                                final isSelected = selectedQr?.id == qr.id;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    provider.setPaymentMethod(
                                      BillingPaymentMethod.qr,
                                    );
                                    provider.selectQrConfig(qr);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primary.withOpacity(
                                              0.12,
                                            )
                                          : colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.network(
                                              qr.imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                    color: colorScheme.surface,
                                                    child: Icon(
                                                      Icons.qr_code_2_rounded,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          qr.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (selectedQr != null) ...[
                              const SizedBox(height: 12),
                              Card(
                                elevation: 0,
                                color: colorScheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text(
                                        selectedQr.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          selectedQr.imageUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => Container(
                                            height: 180,
                                            color: colorScheme.surface,
                                            child: Icon(
                                              Icons.qr_code_2_rounded,
                                              size: 92,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Show this QR to customer to scan and pay.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: canContinue
                                  ? () {
                                      provider.setPaymentMethod(
                                        BillingPaymentMethod.qr,
                                      );
                                      provider.setMarkPaid(true);
                                      Navigator.of(context).pop();
                                    }
                                  : null,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Payment received'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _generateBill() {
    final provider = context.read<BillingProvider>();

    if (provider.items.isEmpty) {
      _showSnack('No products to bill.');
      return;
    }

    if (provider.paymentMethod == null) {
      _showSnack('Please select a payment method.');
      return;
    }

    if (provider.paymentMethod == BillingPaymentMethod.qr &&
        provider.selectedQrConfig == null) {
      _showSnack('Please select a QR barcode.');
      return;
    }

    if (provider.paymentMethod == BillingPaymentMethod.card) {
      _showSnack('Card payment is coming soon.');
      return;
    }

    Navigator.of(context).push(BillPreviewScreen.route(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<BillingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bill summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Total items',
                    value: provider.totalItems.toString(),
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Subtotal',
                    value: _money(provider.originalSubtotal),
                  ),
                  const SizedBox(height: 10),
                  if (provider.customPriceAdjustment + provider.totalDiscount >
                      0) ...[
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Discount',
                      value:
                          '- ${_money(provider.customPriceAdjustment + provider.totalDiscount)}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Final amount',
                    value: _money(provider.finalAmount),
                  ),
                  TextFormField(
                    controller: _paidController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Paid Amount',
                      prefixText: '₹',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Remaining',
                    value: _money(provider.remainingAmount),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                RadioListTile<BillingPaymentMethod>(
                  value: BillingPaymentMethod.cash,
                  groupValue: provider.paymentMethod,
                  onChanged: (v) =>
                      context.read<BillingProvider>().setPaymentMethod(v),
                  title: const Text('Cash'),
                  secondary: const Icon(Icons.payments_outlined),
                ),
                const Divider(height: 0),
                RadioListTile<BillingPaymentMethod>(
                  value: BillingPaymentMethod.qr,
                  groupValue: provider.paymentMethod,
                  onChanged: (v) =>
                      context.read<BillingProvider>().setPaymentMethod(v),
                  title: const Text('QR barcode'),
                  secondary: const Icon(Icons.qr_code_2),
                ),
                const Divider(height: 0),
                RadioListTile<BillingPaymentMethod>(
                  value: BillingPaymentMethod.card,
                  groupValue: provider.paymentMethod,
                  onChanged: (v) =>
                      context.read<BillingProvider>().setPaymentMethod(v),
                  title: const Text('Card (Credit/Debit)'),
                  secondary: const Icon(Icons.credit_card_outlined),
                ),
              ],
            ),
          ),

          if (provider.paymentMethod == BillingPaymentMethod.qr) ...[
            const SizedBox(height: 12),
            Text(
              'Select QR barcode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.selectedQrConfig == null)
                      const Text('No QR barcode selected yet.')
                    else ...[
                      Text(
                        provider.selectedQrConfig!.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            provider.selectedQrConfig!.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              color: colorScheme.surface,
                              child: const Center(
                                child: Icon(Icons.qr_code_2, size: 120),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        provider.selectedQrConfig!.id,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    FutureBuilder<List<BillingQrConfig>>(
                      future: _qrConfigsFuture,
                      builder: (context, snapshot) {
                        return FilledButton.tonalIcon(
                          onPressed:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : _showQrSelectionSheet,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: Text(
                            provider.selectedQrConfig == null
                                ? 'Choose QR barcode'
                                : 'Change QR barcode',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (provider.paymentMethod == BillingPaymentMethod.card) ...[
            const SizedBox(height: 12),
            Card(
              color: colorScheme.surfaceContainerHigh,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Card payment is coming soon.'),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: provider.markPaid,
              onChanged: (v) {
                context.read<BillingProvider>().setMarkPaid(v);
                if (v) {
                  final total = context.read<BillingProvider>().paidAmount;
                  _paidController.text = total.toStringAsFixed(2);
                }
              },
              title: const Text('Mark as Paid'),
              secondary: const Icon(Icons.verified_outlined),
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
              onPressed: _generateBill,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Generate Bill'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
