import 'package:flutter/material.dart';

class ProductScanCard extends StatelessWidget {
  const ProductScanCard({
    super.key,
    required this.productName,
    required this.quantityController,
    required this.costPriceController,
    required this.sellingPriceController,
    required this.allowSellingPriceEdit,
    required this.onRemove,
    required this.onIncrementQty,
    required this.onDecrementQty,
  });

  final String productName;

  final TextEditingController quantityController;
  final TextEditingController costPriceController;
  final TextEditingController sellingPriceController;

  final bool allowSellingPriceEdit;

  final VoidCallback onRemove;
  final VoidCallback onIncrementQty;
  final VoidCallback onDecrementQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    productName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                SizedBox(
                  width: 112,
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Increase quantity',
                      onPressed: onIncrementQty,
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 6),
                    IconButton.filledTonal(
                      tooltip: 'Decrease quantity',
                      onPressed: onDecrementQty,
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Scanned',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: costPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      isDense: true,
                      prefixText: '₹',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: sellingPriceController,
                    enabled: allowSellingPriceEdit,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Selling Price',
                      isDense: true,
                      prefixText: '₹',
                      prefixIcon: const Icon(Icons.sell_outlined),
                      helperText: allowSellingPriceEdit ? null : 'Auto-filled',
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
