import 'package:flutter/material.dart';

import '../models/billing_models.dart';

@immutable
class BillingManualProductResult {
  const BillingManualProductResult({required this.name, required this.price});

  final String name;
  final double price;
}

class BillingManualProductSheet extends StatefulWidget {
  const BillingManualProductSheet({super.key});

  @override
  State<BillingManualProductSheet> createState() =>
      _BillingManualProductSheetState();
}

class _BillingManualProductSheetState extends State<BillingManualProductSheet> {
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
      BillingManualProductResult(
        name: _nameController.text.trim(),
        price: price,
      ),
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
class BillingItemEditResult {
  const BillingItemEditResult({
    this.unitPrice,
    this.discountPercent,
    this.remove = false,
  });

  final double? unitPrice;
  final double? discountPercent;
  final bool remove;
}

class BillingItemEditSheet extends StatefulWidget {
  const BillingItemEditSheet({
    super.key,
    required this.item,
    this.originalUnitPrice,
  });

  final BillingLineItem item;
  final double? originalUnitPrice;

  @override
  State<BillingItemEditSheet> createState() => _BillingItemEditSheetState();
}

class _BillingItemEditSheetState extends State<BillingItemEditSheet> {
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

    Navigator.of(context).pop(
      BillingItemEditResult(unitPrice: unitPrice, discountPercent: discount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = widget.originalUnitPrice ?? widget.item.unitPrice;

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
            const SizedBox(height: 6),
            Text(
              'Original price: ₹${original.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Bill price',
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
                    ).pop(const BillingItemEditResult(remove: true)),
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
