import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';
import '../widgets/billing_bottom_sheets.dart';
import '../widgets/product_item_widget.dart';
import 'bill_preview_screen.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/customer'),
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => BillingProvider(),
          child: const CustomerFormScreen(),
        );
      },
    );
  }

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  bool _showHowBillingWorks = true;
  bool _scanMode = false;

  bool _scannerActive = false;
  bool _startingScanner = false;

  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  String? _lastBarcode;
  DateTime? _lastBarcodeAt;
  bool _handlingBarcode = false;

  final BillingService _billingService = BillingService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  Future<void> _handleBarcode(String barcode) async {
    if (_handlingBarcode) return;
    _handlingBarcode = true;

    try {
      final products = await _billingService.fetchProductsByBarcode(barcode);
      if (!mounted) return;

      if (products.isEmpty) {
        _showSnack('No product found for barcode $barcode');
        await _addUnknownProduct();
        return;
      }

      if (products.length == 1) {
        final selected = products.first;
        context.read<BillingProvider>().addOrIncrementProduct(selected);
        _showSnack('${selected.name} added');
        return;
      }

      final selected = await _pickProductFromMatches(
        barcode: barcode,
        products: products,
      );
      if (!mounted || selected == null) return;

      context.read<BillingProvider>().addOrIncrementProduct(selected);
      _showSnack('${selected.name} added');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Barcode lookup failed. You can add the product manually.');
      await _addUnknownProduct();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _handlingBarcode = false;
    }
  }

  Future<BillingProduct?> _pickProductFromMatches({
    required String barcode,
    required List<BillingProduct> products,
  }) {
    return showModalBottomSheet<BillingProduct>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select product',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Barcode: $barcode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          title: Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Price ${_money(p.unitPrice)}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(p),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmPaymentDone({required String methodLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$methodLabel payment'),
          content: const Text('Is the payment completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<bool> _reviewBillAndApplyFinalAmount() async {
    final provider = context.read<BillingProvider>();
    if (provider.items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return false;
    }

    final controller = TextEditingController(
      text: provider.finalAmount.toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Review bill total'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Items: ${provider.items.length}'),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.items.length,
                    itemBuilder: (context, index) {
                      final item = provider.items[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text('x${item.quantity}'),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Subtotal: ${_money(provider.subtotal)}'),
              const SizedBox(height: 6),
              Text('Discount: ${_money(provider.totalDiscount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Final bill amount',
                  prefixText: '₹',
                  helperText: 'Editable for this bill only',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can adjust total before payment selection.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      controller.dispose();
      return false;
    }

    final parsed = double.tryParse(controller.text.trim());
    controller.dispose();

    if (parsed == null || parsed <= 0) {
      _showSnack('Enter a valid final bill amount');
      return false;
    }

    provider.setManualFinalAmount(parsed);
    return true;
  }

  Future<void> _addUnknownProduct() async {
    final result = await showModalBottomSheet<BillingManualProductResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const BillingManualProductSheet(),
    );

    if (!mounted) return;
    if (result == null) return;

    final item = context.read<BillingProvider>().addManualProduct(
      name: result.name,
      unitPrice: result.price,
    );
    _showSnack('${item.productName} added');
  }

  Future<void> _confirmCashAndGenerateBill() async {
    final confirmed = await _confirmPaymentDone(methodLabel: 'Cash');
    if (!mounted || !confirmed) return;

    final provider = context.read<BillingProvider>();
    provider.setPaymentMethod(BillingPaymentMethod.cash);
    provider.setMarkPaid(true);
    Navigator.of(context).push(BillPreviewScreen.route(context));
  }

  Future<void> _showQrPaymentSheet({
    required BillingPaymentMethod method,
  }) async {
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
                  child: Consumer<BillingProvider>(
                    builder: (context, p, _) {
                      final title = method == BillingPaymentMethod.paytm
                          ? 'Paytm'
                          : 'UPI';
                      final selectedLabel = method == BillingPaymentMethod.paytm
                          ? p.selectedPaytmQr?.label
                          : p.selectedUpiQr?.label;

                      final canContinue = method == BillingPaymentMethod.paytm
                          ? p.selectedPaytmQr != null
                          : p.selectedUpiQr != null;

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
                                  '$title payment',
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
                            'Select a QR and show it to the customer.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (selectedLabel != null)
                            Card(
                              elevation: 0,
                              color: colorScheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      selectedLabel,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 180,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 120,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Show this QR to customer to scan and pay.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),
                          Text(
                            'Choose QR',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (method == BillingPaymentMethod.paytm)
                                ...p.paytmQrs.map(
                                  (qr) => ChoiceChip(
                                    label: Text(qr.label),
                                    selected: p.selectedPaytmQr?.id == qr.id,
                                    onSelected: (_) {
                                      p.setPaymentMethod(
                                        BillingPaymentMethod.paytm,
                                      );
                                      p.selectPaytmQr(qr);
                                    },
                                  ),
                                )
                              else
                                ...p.upiQrs.map(
                                  (qr) => ChoiceChip(
                                    label: Text(qr.label),
                                    selected: p.selectedUpiQr?.id == qr.id,
                                    onSelected: (_) {
                                      p.setPaymentMethod(
                                        BillingPaymentMethod.upi,
                                      );
                                      p.selectUpiQr(qr);
                                    },
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: canContinue
                                  ? () async {
                                      final done = await _confirmPaymentDone(
                                        methodLabel: title,
                                      );
                                      if (!done || !this.context.mounted) {
                                        return;
                                      }
                                      provider.setPaymentMethod(method);
                                      provider.setMarkPaid(true);
                                      Navigator.of(context).pop();
                                      Navigator.of(this.context).push(
                                        BillPreviewScreen.route(this.context),
                                      );
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

  Future<void> _showPaymentOptions() async {
    final provider = context.read<BillingProvider>();

    final canContinue = await _reviewBillAndApplyFinalAmount();
    if (!canContinue) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(icon),
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTap,
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment',
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
                  'Select a payment option to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                option(
                  icon: Icons.payments_outlined,
                  title: 'Cash',
                  subtitle: 'Confirm cash received',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _confirmCashAndGenerateBill();
                  },
                ),
                option(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Paytm',
                  subtitle: 'Show QR to customer',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _showQrPaymentSheet(
                      method: BillingPaymentMethod.paytm,
                    );
                  },
                ),
                option(
                  icon: Icons.qr_code_scanner_outlined,
                  title: 'UPI',
                  subtitle: 'Show UPI QR to customer',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _showQrPaymentSheet(method: BillingPaymentMethod.upi);
                  },
                ),
                option(
                  icon: Icons.credit_card_outlined,
                  title: 'Card (Credit/Debit)',
                  subtitle: 'Coming soon',
                  onTap: () {
                    Navigator.of(context).pop();
                    showDialog<void>(
                      context: this.context,
                      builder: (context) => AlertDialog(
                        title: const Text('Coming soon'),
                        content: const Text(
                          'Card payments will be available in a future update.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _validateRequired(String? value, {required String label}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';

    final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 8) return 'Enter a valid phone number';

    return null;
  }

  Future<void> _start() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      _showSnack('Please fix highlighted fields.');
      return;
    }

    final customer = BillingCustomer(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );

    final provider = context.read<BillingProvider>();
    provider.setCustomer(customer);

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _scanMode = true;
      _scannerActive = false;
      _startingScanner = false;
      _showHowBillingWorks = false;
    });

    await _startScanner();
  }

  Future<void> _startScanner() async {
    if (_startingScanner || _scannerActive) return;
    setState(() => _startingScanner = true);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await _scannerController.start();
      if (!mounted) return;
      setState(() {
        _scannerActive = true;
        _startingScanner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerActive = false;
        _startingScanner = false;
      });
      _showSnack(
        'Camera could not start on this device. Use manual add or try again.',
      );
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() {
      _scannerActive = false;
      _startingScanner = false;
    });
  }

  void _editCustomer() {
    unawaited(_stopScanner());
    setState(() => _scanMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final billingProvider = context.read<BillingProvider>();
    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? helper,
    }) {
      return InputDecoration(
        isDense: true,
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surfaceContainerLow.withAlpha(235),
        surfaceTintColor: colorScheme.surfaceTint,
        title: _scanMode
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Billing',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    customer == null
                        ? 'Customer not selected'
                        : '${customer.name} • ${customer.phone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                ],
              )
            : const Text(
                'Start billing',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
        actions: _scanMode
            ? [
                IconButton(
                  tooltip: 'Edit customer',
                  onPressed: _editCustomer,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        bottom: false,
        child: _scanMode
            ? Builder(
                builder: (context) {
                  final totals = Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Items ${provider.totalItems} • Subtotal ${_money(provider.subtotal)} • Discount ${_money(provider.totalDiscount)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _money(provider.finalAmount),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        sliver: SliverToBoxAdapter(
                          child: Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: _scannerActive
                                      ? MobileScanner(
                                          controller: _scannerController,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, child) {
                                            return Container(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    16,
                                                  ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.camera_alt_outlined,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Camera unavailable',
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'This emulator/device may not support camera scanning.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    FilledButton.icon(
                                                      onPressed: () {
                                                        unawaited(
                                                          _stopScanner(),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                      ),
                                                      label: const Text(
                                                        'Close scanner',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          onDetect: (capture) {
                                            final barcodes = capture.barcodes;
                                            if (barcodes.isEmpty) return;

                                            final raw = barcodes.first.rawValue;
                                            final value = raw?.trim();
                                            if (value == null ||
                                                value.isEmpty) {
                                              return;
                                            }

                                            final now = DateTime.now();
                                            final last = _lastBarcodeAt;
                                            final same = _lastBarcode == value;
                                            final tooSoon =
                                                last != null &&
                                                now.difference(last) <
                                                    const Duration(
                                                      milliseconds: 1200,
                                                    );
                                            if (same && tooSoon) return;

                                            _lastBarcode = value;
                                            _lastBarcodeAt = now;

                                            unawaited(_handleBarcode(value));
                                          },
                                        )
                                      : Container(
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            16,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  height: 44,
                                                  width: 44,
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.primary
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .qr_code_scanner_rounded,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Camera scanning is off',
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Start scanning to add products faster.',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                FilledButton.icon(
                                                  onPressed: _startingScanner
                                                      ? null
                                                      : () {
                                                          unawaited(
                                                            _startScanner(),
                                                          );
                                                        },
                                                  icon: _startingScanner
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .camera_alt_rounded,
                                                        ),
                                                  label: Text(
                                                    _startingScanner
                                                        ? 'Starting…'
                                                        : 'Start scanning',
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                TextButton(
                                                  onPressed: () {
                                                    unawaited(
                                                      _addUnknownProduct(),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Add product manually',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerLow
                                          .withAlpha(235),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.qr_code_scanner),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _scannerActive
                                                ? 'Keep scanning products one by one. The bill updates automatically.'
                                                : 'Tap “Start scanning” to use camera. You can also add products manually.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        sliver: SliverToBoxAdapter(child: totals),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Scanned items (${provider.items.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      if (provider.items.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 220),
                          sliver: SliverToBoxAdapter(
                            child: Card(
                              elevation: 0,
                              color: colorScheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No products yet. Point the camera at a barcode to scan.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 220),
                          sliver: SliverList.separated(
                            itemCount: provider.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = provider.items[index];
                              return ProductItemWidget(
                                item: item,
                                onPriceChanged: (v) {
                                  context
                                      .read<BillingProvider>()
                                      .updateItemPrice(item.id, v);
                                },
                                onDiscountChanged: (v) {
                                  context
                                      .read<BillingProvider>()
                                      .updateItemDiscountPercent(item.id, v);
                                },
                                onIncrement: () {
                                  context
                                      .read<BillingProvider>()
                                      .incrementItemQuantity(item.id);
                                },
                                onDecrement: () {
                                  context
                                      .read<BillingProvider>()
                                      .decrementItemQuantity(item.id);
                                },
                                onRemove: () {
                                  context.read<BillingProvider>().removeItem(
                                    item.id,
                                  );
                                  _showSnack('Removed ${item.productName}');
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final header = Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.account_circle_outlined,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer details',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Basic info to start a new bill.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'Step 1 of 2',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final formCard = Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Customer',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We’ll use this for bills and history.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RawAutocomplete<BillingCustomer>(
                              textEditingController: _nameController,
                              focusNode: _nameFocusNode,
                              displayStringForOption: (c) => c.name,
                              optionsBuilder: (textEditingValue) {
                                final q = textEditingValue.text;
                                if (q.trim().isEmpty) {
                                  return const Iterable<
                                    BillingCustomer
                                  >.empty();
                                }
                                return billingProvider.searchCustomers(q);
                              },
                              onSelected: (customer) {
                                _nameController.text = customer.name;
                                _nameController.selection =
                                    TextSelection.collapsed(
                                      offset: customer.name.length,
                                    );
                                _phoneController.text = customer.phone;
                                _phoneController.selection =
                                    TextSelection.collapsed(
                                      offset: customer.phone.length,
                                    );
                                _addressController.text =
                                    customer.address ?? '';
                                _addressController.selection =
                                    TextSelection.collapsed(
                                      offset: _addressController.text.length,
                                    );

                                FocusScope.of(
                                  context,
                                ).requestFocus(_phoneFocusNode);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      textInputAction: TextInputAction.next,
                                      decoration: fieldDecoration(
                                        label: 'Customer name',
                                        icon: Icons.person_outline,
                                        helper:
                                            'Start typing to search existing customers.',
                                      ),
                                      validator: (v) => _validateRequired(
                                        v,
                                        label: 'Customer name',
                                      ),
                                      onFieldSubmitted: (_) {
                                        onFieldSubmitted();
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(_phoneFocusNode);
                                      },
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 6,
                                        borderRadius: BorderRadius.circular(16),
                                        clipBehavior: Clip.antiAlias,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 560,
                                            maxHeight: 260,
                                          ),
                                          child: ListView.separated(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            separatorBuilder: (_, _) =>
                                                const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final c = options.elementAt(
                                                index,
                                              );
                                              return ListTile(
                                                leading: const Icon(
                                                  Icons.person_outline,
                                                ),
                                                title: Text(
                                                  c.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(
                                                  c.phone,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onTap: () => onSelected(c),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: fieldDecoration(
                                label: 'Phone number',
                                icon: Icons.phone_outlined,
                                helper:
                                    'Used for bill history / WhatsApp invoice (later).',
                              ),
                              validator: _validatePhone,
                              onFieldSubmitted: (_) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_addressFocusNode);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              focusNode: _addressFocusNode,
                              keyboardType: TextInputType.streetAddress,
                              textInputAction: TextInputAction.done,
                              decoration: fieldDecoration(
                                label: 'Address (optional)',
                                icon: Icons.location_on_outlined,
                              ),
                              minLines: 1,
                              maxLines: 3,
                              onFieldSubmitted: (_) => _start(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final sidePanel = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showHowBillingWorks)
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'How billing works',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Close',
                                      onPressed: () {
                                        setState(
                                          () => _showHowBillingWorks = false,
                                        );
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colorScheme.primary
                                        .withOpacity(0.12),
                                    child: Text(
                                      '1',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  title: const Text('Enter customer'),
                                  subtitle: const Text('Name and phone number'),
                                ),
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colorScheme.primary
                                        .withOpacity(0.12),
                                    child: Text(
                                      '2',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  title: const Text('Scan products'),
                                  subtitle: const Text('Add items to the bill'),
                                ),
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colorScheme.primary
                                        .withOpacity(0.12),
                                    child: Text(
                                      '3',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  title: const Text('Take payment'),
                                  subtitle: const Text('UPI / Cash / Card'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.privacy_tip_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Customer details are only used for billing and invoice reference.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  return CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: header),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: formCard),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: sidePanel),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _scanMode
              ? Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Items ${provider.totalItems}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Subtotal ${_money(provider.subtotal)} • Discount ${_money(provider.totalDiscount)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: provider.items.isEmpty
                              ? null
                              : _showPaymentOptions,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Payment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Continue to Scan'),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
