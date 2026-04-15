import 'package:flutter/material.dart';

import '../models/billing_models.dart';

enum _EditMode { price, discount }

class ProductItemWidget extends StatefulWidget {
  const ProductItemWidget({
    super.key,
    required this.item,
    required this.onPriceChanged,
    required this.onDiscountChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final BillingLineItem item;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  State<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends State<ProductItemWidget> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  _EditMode _mode = _EditMode.price;
  bool _showOfferEditor = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromItem();
  }

  @override
  void didUpdateWidget(covariant ProductItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.unitPrice != widget.item.unitPrice ||
        oldWidget.item.discountPercent != widget.item.discountPercent) {
      _syncControllersFromItem();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _syncControllersFromItem() {
    _priceController.text = widget.item.unitPrice.toStringAsFixed(2);
    _discountController.text = widget.item.discountPercent
        .clamp(0, 100)
        .toStringAsFixed(0);
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    InputDecoration fieldDecoration({required String label, String? suffix}) {
      return InputDecoration(
        isDense: true,
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    widget.item.quantity.toString(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.productName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _Chip(
                            icon: Icons.tag,
                            label: 'Price ${_money(widget.item.unitPrice)}',
                          ),
                          _Chip(
                            icon: Icons.percent,
                            label:
                                'Disc ${widget.item.discountPercent.toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(widget.item.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _money(widget.item.lineSubtotal),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        decoration: widget.item.lineDiscount > 0
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Offer / price override',
                          onPressed: () {
                            setState(
                              () => _showOfferEditor = !_showOfferEditor,
                            );
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: Icon(
                            _showOfferEditor
                                ? Icons.local_offer
                                : Icons.local_offer_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: widget.onRemove,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Decrease quantity',
                        onPressed: widget.item.quantity > 1
                            ? widget.onDecrement
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        widget.item.quantity.toString(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase quantity',
                        onPressed: widget.onIncrement,
                        icon: const Icon(Icons.add_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Qty controls for this product',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (_showOfferEditor) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_EditMode>(
                          value: _mode,
                          isDense: true,
                          borderRadius: BorderRadius.circular(14),
                          items: const [
                            DropdownMenuItem(
                              value: _EditMode.price,
                              child: Text('Price'),
                            ),
                            DropdownMenuItem(
                              value: _EditMode.discount,
                              child: Text('Discount'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _mode = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      enabled: _mode == _EditMode.price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: fieldDecoration(
                        label: 'Unit price',
                        suffix: '₹',
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) return;
                        widget.onPriceChanged(parsed.clamp(0, double.infinity));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      enabled: _mode == _EditMode.discount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: fieldDecoration(
                        label: 'Discount',
                        suffix: '%',
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) return;
                        widget.onDiscountChanged(parsed.clamp(0, 100));
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Reset discount',
                    onPressed: () {
                      _discountController.text = '0';
                      widget.onDiscountChanged(0);
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
