import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../widgets/product_item_widget.dart';
import 'bill_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  static Route<void> route(BuildContext context) {
    final provider = context.read<BillingProvider>();
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/scan'),
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const BillingScreen(),
        );
      },
    );
  }

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  String? _lastBarcode;
  DateTime? _lastBarcodeAt;
  bool _handlingBarcode = false;

  final List<BillingProduct> _catalog = const [
    BillingProduct(
      id: 'p_001',
      name: 'Parle-G 250g',
      unitPrice: 20.0,
      barcode: '8901719100187',
    ),
    BillingProduct(
      id: 'p_002',
      name: 'Aashirvaad Atta 5kg',
      unitPrice: 275.0,
      barcode: '8906007280015',
    ),
    BillingProduct(
      id: 'p_003',
      name: 'Coca-Cola 750ml',
      unitPrice: 40.0,
      barcode: '5449000131805',
    ),
    BillingProduct(
      id: 'p_004',
      name: 'Lux Soap',
      unitPrice: 35.0,
      barcode: '8901030824037',
    ),
    BillingProduct(
      id: 'p_005',
      name: 'Colgate Toothpaste 200g',
      unitPrice: 95.0,
      barcode: '8901023012218',
    ),
  ];

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  BillingProduct? _findProductByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;

    for (final p in _catalog) {
      final b = p.barcode?.trim();
      if (b != null && b.isNotEmpty && b == normalized) return p;
    }
    return null;
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_handlingBarcode) return;
    _handlingBarcode = true;

    try {
      final product = _findProductByBarcode(barcode);
      if (product != null) {
        context.read<BillingProvider>().addOrIncrementProduct(product);
        _showSnack('${product.name} added');
        return;
      }

      await _addUnknownProduct();
    } finally {
      // Small cooldown to avoid rapid repeats from the camera.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _handlingBarcode = false;
    }
  }

  Future<void> _addUnknownProduct() async {
    final result = await showModalBottomSheet<_ManualProductResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ManualProductSheet(),
    );

    if (!mounted) return;
    if (result == null) return;

    context.read<BillingProvider>().addManualProduct(
      name: result.name,
      unitPrice: result.price,
    );

    _showSnack('${result.name} added');
  }

  Future<void> _editItem(BillingLineItem item) async {
    final action = await showModalBottomSheet<_ItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ItemEditSheet(item: item),
    );

    if (!mounted) return;
    if (action == null) return;

    final provider = context.read<BillingProvider>();

    if (action.remove) {
      provider.removeItem(item.id);
      _showSnack('Removed ${item.productName}');
      return;
    }

    if (action.unitPrice != null) {
      provider.updateItemPrice(item.id, action.unitPrice!);
    }
    if (action.discountPercent != null) {
      provider.updateItemDiscountPercent(item.id, action.discountPercent!);
    }

    _showSnack('Updated ${item.productName}');
  }

  Future<void> _confirmCashAndGenerateBill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cash payment'),
          content: const Text('Did you receive payment from customer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

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
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            children: [
                              Text(
                                selectedLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
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
                                p.setPaymentMethod(BillingPaymentMethod.paytm);
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
                                p.setPaymentMethod(BillingPaymentMethod.upi);
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
                            ? () {
                                provider.setPaymentMethod(method);
                                provider.setMarkPaid(true);
                                Navigator.of(context).pop();
                                Navigator.of(
                                  this.context,
                                ).push(BillPreviewScreen.route(this.context));
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
    );
  }

  Future<void> _showPaymentOptions() async {
    final provider = context.read<BillingProvider>();

    if (provider.items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return;
    }

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

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    final totals = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live totals',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Items ${provider.totalItems} • Subtotal ${_money(provider.subtotal)} • Discount ${_money(provider.totalDiscount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _money(provider.finalAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer == null
                        ? 'Customer'
                        : '${customer.name} • ${customer.phone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: MobileScanner(
                        controller: _scannerController,
                        fit: BoxFit.cover,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;

                          final raw = barcodes.first.rawValue;
                          final value = raw?.trim();
                          if (value == null || value.isEmpty) return;

                          final now = DateTime.now();
                          final last = _lastBarcodeAt;
                          final same = _lastBarcode == value;
                          final tooSoon =
                              last != null &&
                              now.difference(last) <
                                  const Duration(milliseconds: 1200);
                          if (same && tooSoon) return;

                          _lastBarcode = value;
                          _lastBarcodeAt = now;

                          unawaited(_handleBarcode(value));
                        },
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Keep scanning products one by one. The bill updates automatically.',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                'Scanned items',
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: colorScheme.outlineVariant),
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
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return ProductItemWidget(
                    item: item,
                    onTap: () => _editItem(item),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant),
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
                    onPressed: _showPaymentOptions,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _ManualProductResult {
  const _ManualProductResult({required this.name, required this.price});

  final String name;
  final double price;
}

class _ManualProductSheet extends StatefulWidget {
  const _ManualProductSheet();

  @override
  State<_ManualProductSheet> createState() => _ManualProductSheetState();
}

class _ManualProductSheetState extends State<_ManualProductSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final price = double.parse(_priceController.text.trim());
    Navigator.of(context).pop(
      _ManualProductResult(name: _nameController.text.trim(), price: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        top: 10,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unknown product',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter details to add it manually.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Product name is required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₹',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) return 'Enter a valid price';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Add Product'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _ItemEditResult {
  const _ItemEditResult({
    this.unitPrice,
    this.discountPercent,
    this.remove = false,
  });

  final double? unitPrice;
  final double? discountPercent;
  final bool remove;
}

class _ItemEditSheet extends StatefulWidget {
  const _ItemEditSheet({required this.item});

  final BillingLineItem item;

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _priceController = TextEditingController(
    text: widget.item.unitPrice.toStringAsFixed(2),
  );
  late final TextEditingController _discountController = TextEditingController(
    text: widget.item.discountPercent.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _apply() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final unitPrice = double.parse(_priceController.text.trim());
    final discount = double.parse(_discountController.text.trim());

    Navigator.of(
      context,
    ).pop(_ItemEditResult(unitPrice: unitPrice, discountPercent: discount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        top: 10,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item.productName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Edit Original Price',
                prefixText: '₹',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Apply Discount (%)',
                prefixIcon: Icon(Icons.percent),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed < 0 || parsed > 100) {
                  return 'Enter 0 to 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _ItemEditResult(remove: true)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Remove'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Apply'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
