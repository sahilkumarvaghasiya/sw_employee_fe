import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
    this.priceEntryAsUnitPrice = false,
  });

  final BillingLineItem item;
  final ValueChanged<double?> onPriceChanged;
  final ValueChanged<double?> onDiscountChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final bool priceEntryAsUnitPrice;

  @override
  State<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends State<ProductItemWidget> {
  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  bool get _priceOverridden =>
      widget.item.unitPrice != widget.item.originalUnitPrice;

  bool get _discountApplied => widget.item.discountPercent > 0;

  bool get _hasOffer => _priceOverridden || _discountApplied;

  Future<void> _openOfferSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _OfferEditSheet(
        item: widget.item,
        priceEntryAsUnitPrice: widget.priceEntryAsUnitPrice,
        onPriceChanged: widget.onPriceChanged,
        onDiscountChanged: widget.onDiscountChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sizeText = widget.item.size?.trim() ?? '';

    final maxQuantity = widget.item.availableQuantity;
    final canIncrement =
        maxQuantity == null || widget.item.quantity < maxQuantity;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.slate200,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (sizeText.isNotEmpty) ...[
                          _MetaTag(text: sizeText, icon: Icons.straighten_rounded),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${_money(widget.item.unitPrice)} each',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: widget.onRemove,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyStepper(
                quantity: widget.item.quantity,
                canIncrement: canIncrement,
                onDecrement: widget.onDecrement,
                onIncrement: widget.onIncrement,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_hasOffer &&
                        widget.item.originalUnitPrice * widget.item.quantity >
                            widget.item.lineTotal + 0.0001)
                      Text(
                        _money(
                          widget.item.originalUnitPrice * widget.item.quantity,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      _money(widget.item.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _hasOffer
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openOfferSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasOffer
                              ? Icons.local_offer_rounded
                              : Icons.percent_rounded,
                          size: 16,
                          color: _hasOffer
                              ? AppColors.emerald
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasOffer ? 'Edit' : 'Offer',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _hasOffer
                                ? AppColors.emeraldDark
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hasOffer) ...[
            const SizedBox(height: 8),
            _OfferSummaryChip(
              item: widget.item,
              priceEntryAsUnitPrice: widget.priceEntryAsUnitPrice,
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferSummaryChip extends StatelessWidget {
  const _OfferSummaryChip({
    required this.item,
    required this.priceEntryAsUnitPrice,
  });

  final BillingLineItem item;
  final bool priceEntryAsUnitPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];

    if (item.discountPercent > 0) {
      parts.add('${item.discountPercent.toStringAsFixed(0)}% off');
    }
    if (item.unitPrice != item.originalUnitPrice) {
      parts.add(
        priceEntryAsUnitPrice
            ? 'Custom ₹${item.unitPrice.toStringAsFixed(0)}/pc'
            : 'Price adjusted',
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          parts.join(' · '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.emeraldDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            onPressed: quantity > 1 ? onDecrement : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: onPressed != null
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.slate500),
          const SizedBox(width: 3),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for price / discount — keeps line items compact on the main bill.
class _OfferEditSheet extends StatefulWidget {
  const _OfferEditSheet({
    required this.item,
    required this.priceEntryAsUnitPrice,
    required this.onPriceChanged,
    required this.onDiscountChanged,
  });

  final BillingLineItem item;
  final bool priceEntryAsUnitPrice;
  final ValueChanged<double?> onPriceChanged;
  final ValueChanged<double?> onDiscountChanged;

  @override
  State<_OfferEditSheet> createState() => _OfferEditSheetState();
}

class _OfferEditSheetState extends State<_OfferEditSheet> {
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  String? _priceError;
  String? _discountError;
  int _mode = 0;

  @override
  void initState() {
    super.initState();
    final priceOverridden =
        widget.item.unitPrice != widget.item.originalUnitPrice;
    final discountApplied = widget.item.discountPercent > 0;

    _priceController = TextEditingController(
      text: widget.priceEntryAsUnitPrice
          ? (priceOverridden ? widget.item.unitPrice.toStringAsFixed(2) : '')
          : priceOverridden
          ? ((widget.item.originalUnitPrice - widget.item.unitPrice) *
                    widget.item.quantity)
                .toStringAsFixed(2)
          : '',
    );
    _discountController = TextEditingController(
      text: discountApplied
          ? widget.item.discountPercent.toStringAsFixed(0)
          : '',
    );

    if (discountApplied) {
      _mode = 2;
    } else if (priceOverridden) {
      _mode = 1;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
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

    if (widget.priceEntryAsUnitPrice) {
      setState(() => _priceError = null);
      widget.onPriceChanged(parsed);
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

  void _clearAll() {
    widget.onPriceChanged(null);
    widget.onDiscountChanged(null);
    _priceController.clear();
    _discountController.clear();
    setState(() {
      _priceError = null;
      _discountError = null;
      _mode = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.productName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Original ${_money(widget.item.originalUnitPrice)} × ${widget.item.quantity}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Custom price'), icon: Icon(Icons.currency_rupee, size: 16)),
              ButtonSegment(value: 2, label: Text('Discount %'), icon: Icon(Icons.percent, size: 16)),
            ],
            selected: _mode == 0 ? <int>{} : {_mode},
            emptySelectionAllowed: true,
            onSelectionChanged: (selected) {
              setState(() {
                if (selected.isEmpty) {
                  _mode = 0;
                } else {
                  _mode = selected.first;
                }
              });
            },
          ),
          const SizedBox(height: 14),
          if (_mode == 1)
            TextField(
              controller: _priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.priceEntryAsUnitPrice
                    ? 'Unit price'
                    : 'Total reduction',
                prefixText: '₹ ',
                errorText: _priceError,
                hintText: widget.priceEntryAsUnitPrice ? 'e.g. 450' : 'Amount off total',
              ),
              onChanged: _handlePriceChanged,
            )
          else if (_mode == 2)
            TextField(
              controller: _discountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Discount percentage',
                suffixText: '%',
                errorText: _discountError,
                hintText: '1 – 100',
              ),
              onChanged: _handleDiscountChanged,
            )
          else
            Text(
              'Select custom price or discount above',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  child: const Text('Clear offer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
