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
          ? (widget.item.originalUnitPrice - widget.item.unitPrice)
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

    final original = widget.item.originalUnitPrice;
    if (parsed >= original) {
      setState(() => _priceError = 'Must be less than ${_money(original)}');
      return;
    }

    setState(() => _priceError = null);
    widget.onPriceChanged(original - parsed);
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

    InputDecoration fieldDecoration({required String label, String? suffix}) {
      return InputDecoration(
        isDense: true,
        hintText: label,
        suffixText: suffix,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
      );
    }

    Widget quantityStepper() {
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
              tooltip: 'Increase quantity',
              onPressed: widget.onIncrement,
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

    Widget symbolBox() {
      return Container(
        width: 42,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          _mode == _EditMode.price ? '₹' : '%',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Widget editorRow() {
      return Row(
        children: [
          modeSelector(),
          const SizedBox(width: 8),
          symbolBox(),
          const SizedBox(width: 8),
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
                    label: _mode == _EditMode.price
                        ? 'Enter reduction'
                        : 'Enter discount',
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
          'Tap to edit price or discount',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (priceOverridden)
            _Chip(
              icon: Icons.sell_outlined,
              label:
                  'Price ${_money(widget.item.unitPrice)} (-${_money(widget.item.originalUnitPrice - widget.item.unitPrice)})',
            ),
          if (discountApplied)
            _Chip(
              icon: Icons.percent_rounded,
              label:
                  'Discount ${widget.item.discountPercent.toStringAsFixed(0)}%',
            ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _showOfferEditor = !_showOfferEditor);
          },
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
                          Text(
                            widget.item.productName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: widget.onRemove,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _money(widget.item.lineTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (hasOffer) ...[
                          const SizedBox(height: 2),
                          Text(
                            _money(widget.item.lineSubtotal),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
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
                if (_showOfferEditor) ...[
                  const SizedBox(height: 12),
                  editorRow(),
                  if (_mode == _EditMode.price &&
                      widget.item.unitPrice !=
                          widget.item.originalUnitPrice) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Original ${_money(widget.item.originalUnitPrice)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_mode == _EditMode.discount &&
                      widget.item.discountPercent == 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Leave empty for no discount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ],
            ),
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
