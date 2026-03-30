import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
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

  @override
  void initState() {
    super.initState();
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

    if (provider.paymentMethod == BillingPaymentMethod.paytm &&
        provider.selectedPaytmQr == null) {
      _showSnack('Please select a Paytm QR code.');
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
                    label: 'Total amount',
                    value: _money(provider.finalAmount),
                  ),
                  const SizedBox(height: 10),
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
                  value: BillingPaymentMethod.upi,
                  groupValue: provider.paymentMethod,
                  onChanged: (v) =>
                      context.read<BillingProvider>().setPaymentMethod(v),
                  title: const Text('UPI'),
                  secondary: const Icon(Icons.qr_code_2),
                ),
                const Divider(height: 0),
                RadioListTile<BillingPaymentMethod>(
                  value: BillingPaymentMethod.paytm,
                  groupValue: provider.paymentMethod,
                  onChanged: (v) =>
                      context.read<BillingProvider>().setPaymentMethod(v),
                  title: const Text('Paytm'),
                  secondary: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
            ),
          ),

          if (provider.paymentMethod == BillingPaymentMethod.paytm) ...[
            const SizedBox(height: 12),
            Text(
              'Select Paytm QR',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final qr in provider.paytmQrs) ...[
                    RadioListTile<PaytmQrCode>(
                      value: qr,
                      groupValue: provider.selectedPaytmQr,
                      onChanged: (v) =>
                          context.read<BillingProvider>().selectPaytmQr(v),
                      title: Text(qr.label),
                      secondary: const Icon(Icons.qr_code),
                    ),
                    if (qr != provider.paytmQrs.last) const Divider(height: 0),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (provider.selectedPaytmQr != null)
              Card(
                color: colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(
                        provider.selectedPaytmQr!.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_2, size: 120),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'QR (dummy) • ${provider.selectedPaytmQr!.id}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
