import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../widgets/product_item_widget.dart';
import 'payment_screen.dart';

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
  int _catalogIndex = 0;

  final List<BillingProduct> _catalog = const [
    BillingProduct(id: 'p_001', name: 'Parle-G 250g', unitPrice: 20.0),
    BillingProduct(id: 'p_002', name: 'Aashirvaad Atta 5kg', unitPrice: 275.0),
    BillingProduct(id: 'p_003', name: 'Coca-Cola 750ml', unitPrice: 40.0),
    BillingProduct(id: 'p_004', name: 'Lux Soap', unitPrice: 35.0),
    BillingProduct(
      id: 'p_005',
      name: 'Colgate Toothpaste 200g',
      unitPrice: 95.0,
    ),
  ];

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  Future<void> _scanSimulated() async {
    // Simulated scanning for now (fast + deterministic).
    // Every 6th scan behaves like an unknown product.
    if ((_catalogIndex + 1) % 6 == 0) {
      _catalogIndex++;
      await _addUnknownProduct();
      return;
    }

    final product = _catalog[_catalogIndex % _catalog.length];
    _catalogIndex++;

    context.read<BillingProvider>().addOrIncrementProduct(product);
    _showSnack('${product.name} added');
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

  void _proceedToPayment() {
    final provider = context.read<BillingProvider>();

    if (provider.items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return;
    }

    Navigator.of(context).push(PaymentScreen.route(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Billing'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 220),
        children: [
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scanner',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to scan and add products (simulated)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanSimulated,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Scan Product'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live bill summary',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
          ),

          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Total items',
            value: provider.totalItems.toString(),
          ),
          _SummaryRow(label: 'Subtotal', value: _money(provider.subtotal)),
          _SummaryRow(
            label: 'Total discount',
            value: _money(provider.totalDiscount),
          ),
          const Divider(height: 24),

          Text(
            'Scanned products',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          if (provider.items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No products yet. Tap Scan Product to add items.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              itemCount: provider.items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = provider.items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == provider.items.length - 1 ? 0 : 10,
                  ),
                  child: ProductItemWidget(
                    item: item,
                    onTap: () => _editItem(item),
                  ),
                );
              },
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
                child: FilledButton.icon(
                  onPressed: _scanSimulated,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Scan Next'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _proceedToPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Proceed to Payment'),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
