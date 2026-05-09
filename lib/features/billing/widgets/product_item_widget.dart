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

  _EditMode _mode = _EditMode.price;
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

    if (force || (!_priceFocusNode.hasFocus && !_discountFocusNode.hasFocus)) {
      _mode = discountApplied && !priceOverridden
          ? _EditMode.discount
          : _EditMode.price;
    }

    if (!_priceFocusNode.hasFocus) {
      _priceError = null;
    }
    if (!_discountFocusNode.hasFocus) {
      _discountError = null;
    }
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  void _setMode(_EditMode mode) {
    final isPriceActive =
        widget.item.unitPrice != widget.item.originalUnitPrice;
    final isDiscountActive = widget.item.discountPercent > 0;

    if (mode == _EditMode.discount && isPriceActive) {
      widget.onPriceChanged(null);
    }
    if (mode == _EditMode.price && isDiscountActive) {
      widget.onDiscountChanged(null);
    }

    setState(() {
      _mode = mode;
      _priceError = null;
      _discountError = null;
    });
  }

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
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
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
          borderRadius: BorderRadius.circular(16),
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

    Widget modeSelector() {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_EditMode>(
              value: _mode,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: _EditMode.price, child: Text('Price')),
                DropdownMenuItem(
                  value: _EditMode.discount,
                  child: Text('Discount'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _setMode(value);
              },
            ),
          ),
        ),
      );
    }

    Widget editorRow() {
      return Row(
        children: [
          SizedBox(width: 84, child: modeSelector()),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _mode == _EditMode.price
                  ? _priceController
                  : _discountController,
              focusNode: _mode == _EditMode.price
                  ? _priceFocusNode
                  : _discountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration:
                  fieldDecoration(
                    prefixText: _mode == _EditMode.price ? '₹' : '%',
                  ).copyWith(
                    errorText: _mode == _EditMode.price
                        ? _priceError
                        : _discountError,
                  ),
              onChanged: _mode == _EditMode.price
                  ? _handlePriceChanged
                  : _handleDiscountChanged,
            ),
          ),
        ],
      );
    }

    Widget offerSummary() {
      if (!hasOffer) {
        return Text(
          'Tap to edit',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      return Text(
        'Offer applied',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 30),
                                child: Text(
                                  widget.item.productName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: TextButton(
                                  onPressed: widget.onRemove,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 0,
                                    ),
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sizeText.isNotEmpty) ...[
                          const SizedBox(height: 6),
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
              Align(
                alignment: Alignment.topRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(widget.item.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (showPreviousAmount) ...[
                      const SizedBox(height: 2),
                      Text(
                        _money(previousAmount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _showOfferEditor = !_showOfferEditor);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      quantityStepper(),
                      const SizedBox(width: 10),
                      Expanded(child: offerSummary()),
                      const SizedBox(width: 10),
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
                editorRow(),
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
