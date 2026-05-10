import 'package:flutter/material.dart';

import '../models/billing_models.dart';

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
  final ValueChanged<double?> onPriceChanged;
  final ValueChanged<double?> onDiscountChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  State<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends State<ProductItemWidget> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();

  bool _showOfferEditor = false;
  String? _priceError;
  String? _discountError;

  @override
  void initState() {
    super.initState();
    _syncControllersFromItem(force: true);
  }

  @override
  void didUpdateWidget(covariant ProductItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.unitPrice != widget.item.unitPrice ||
        oldWidget.item.discountPercent != widget.item.discountPercent ||
        oldWidget.item.originalUnitPrice != widget.item.originalUnitPrice ||
        oldWidget.item.size != widget.item.size) {
      _syncControllersFromItem();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    _priceFocusNode.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  void _syncControllersFromItem({bool force = false}) {
    final priceOverridden =
        widget.item.unitPrice != widget.item.originalUnitPrice;
    final discountApplied = widget.item.discountPercent > 0;

    if (force || !_priceFocusNode.hasFocus) {
      final priceText = priceOverridden
          ? ((widget.item.originalUnitPrice - widget.item.unitPrice) *
                    widget.item.quantity)
                .toStringAsFixed(2)
          : '';
      if (_priceController.text != priceText) {
        _priceController.text = priceText;
      }
    }

    if (force || !_discountFocusNode.hasFocus) {
      final discountText = discountApplied
          ? widget.item.discountPercent.toStringAsFixed(0)
          : '';
      if (_discountController.text != discountText) {
        _discountController.text = discountText;
      }
    }

    if (force) {
      // Mode auto-detection only on force (initial load)
    }

    if (!_priceFocusNode.hasFocus) {
      _priceError = null;
    }
    if (!_discountFocusNode.hasFocus) {
      _discountError = null;
    }
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  void _handlePriceChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _priceError = null);
      widget.onPriceChanged(null);
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() => _priceError = 'Invalid entry');
      return;
    }

    final qty = widget.item.quantity <= 0 ? 1 : widget.item.quantity;
    final originalTotal = widget.item.originalUnitPrice * qty;
    if (parsed >= originalTotal) {
      setState(
        () => _priceError = 'Must be less than ${_money(originalTotal)}',
      );
      return;
    }

    final nextUnitPrice = widget.item.originalUnitPrice - (parsed / qty);
    setState(() => _priceError = null);
    widget.onPriceChanged(nextUnitPrice);
  }

  void _handleDiscountChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _discountError = null);
      widget.onDiscountChanged(null);
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 100) {
      setState(() => _discountError = 'Enter 1 to 100');
      return;
    }

    setState(() => _discountError = null);
    widget.onDiscountChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sizeText = widget.item.size?.trim() ?? '';
    final priceOverridden =
        widget.item.unitPrice != widget.item.originalUnitPrice;
    final discountApplied = widget.item.discountPercent > 0;
    final hasOffer = priceOverridden || discountApplied;
    final previousAmount = priceOverridden
        ? widget.item.originalUnitPrice * widget.item.quantity
        : widget.item.lineSubtotal;
    final showPreviousAmount =
        hasOffer && previousAmount > widget.item.lineTotal + 0.0001;

    InputDecoration fieldDecoration({String? prefixText}) {
      return InputDecoration(
        isDense: true,
        prefixText: prefixText,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      );
    }

    Widget quantityStepper() {
      final maxQuantity = widget.item.availableQuantity;
      final canIncrement =
          maxQuantity == null || widget.item.quantity < maxQuantity;
      final incrementTooltip = canIncrement
          ? 'Increase quantity'
          : 'Maximum available quantity reached';

      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease quantity',
              onPressed: widget.item.quantity > 1 ? widget.onDecrement : null,
              icon: const Icon(Icons.remove_rounded),
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 30,
              child: Text(
                widget.item.quantity.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: incrementTooltip,
              onPressed: canIncrement ? widget.onIncrement : null,
              icon: const Icon(Icons.add_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    Widget priceDiscountEditor() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Custom Price',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _priceController,
                        focusNode: _priceFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: fieldDecoration(prefixText: '₹').copyWith(
                          hintText: 'Enter amount',
                          errorText: _priceError,
                        ),
                        onChanged: _handlePriceChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Discount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _discountController,
                        focusNode: _discountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: fieldDecoration(prefixText: '%').copyWith(
                          hintText: 'Enter %',
                          errorText: _discountError,
                        ),
                        onChanged: _handleDiscountChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      widget.onPriceChanged(null);
                      widget.onDiscountChanged(null);
                      setState(() => _showOfferEditor = false);
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() => _showOfferEditor = false);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget offerSummary() {
      if (!hasOffer) {
        return Text(
          'No offer applied • Tap to add price or discount',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      final parts = <String>[];
      if (discountApplied) {
        parts.add(
          'Discount ${widget.item.discountPercent.toStringAsFixed(0)}%',
        );
      }
      if (priceOverridden) {
        final reduction = widget.item.originalUnitPrice - widget.item.unitPrice;
        parts.add('Price reduced by ${_money(reduction)} each');
      }

      return Text(
        parts.join(' • '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Widget amountBox({
      required String value,
      required Color backgroundColor,
      required Color borderColor,
      required Color valueColor,
      bool strike = false,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  decoration: strike ? TextDecoration.lineThrough : null,
                  color: strike ? valueColor.withAlpha(190) : valueColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primary.withOpacity(0.12),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.productName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove item',
                              onPressed: widget.onRemove,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (sizeText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _Chip(
                            icon: Icons.straighten_rounded,
                            label: sizeText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _showOfferEditor = !_showOfferEditor);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 0,
                  ),
                  child: Row(
                    children: [
                      quantityStepper(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            offerSummary(),
                            const SizedBox(height: 6),
                            if (showPreviousAmount)
                              Row(
                                children: [
                                  Expanded(
                                    child: amountBox(
                                      value: _money(widget.item.lineTotal),
                                      backgroundColor: Colors.green.withAlpha(
                                        28,
                                      ),
                                      borderColor: Colors.green.withAlpha(120),
                                      valueColor: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: amountBox(
                                      value: _money(previousAmount),
                                      backgroundColor: Colors.lightBlue
                                          .withAlpha(28),
                                      borderColor: Colors.lightBlue.withAlpha(
                                        120,
                                      ),
                                      valueColor: Colors.lightBlue.shade800,
                                      strike: true,
                                    ),
                                  ),
                                ],
                              )
                            else
                              amountBox(
                                value: _money(widget.item.lineTotal),
                                backgroundColor: Colors.green.withAlpha(28),
                                borderColor: Colors.green.withAlpha(120),
                                valueColor: Colors.green.shade800,
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        _showOfferEditor
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showOfferEditor) ...[
                const SizedBox(height: 10),
                priceDiscountEditor(),
              ],
            ],
          ),
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
