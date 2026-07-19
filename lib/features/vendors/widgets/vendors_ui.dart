import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/vendor_bill.dart';

/// Renders an INR amount with a font that includes the ₹ glyph.
class InrAmountText extends StatelessWidget {
  const InrAmountText(
    this.amountDisplay, {
    super.key,
    this.style,
    this.prefixSpace = true,
  });

  final String amountDisplay;
  final TextStyle? style;
  final bool prefixSpace;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    final symbolStyle = (base ?? const TextStyle()).copyWith(
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Arial', 'Noto Sans', 'sans-serif'],
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: prefixSpace ? '₹ ' : '₹', style: symbolStyle),
          TextSpan(text: amountDisplay, style: base),
        ],
      ),
    );
  }
}

class PayableTotalCard extends StatelessWidget {
  const PayableTotalCard({
    super.key,
    required this.totalDisplay,
  });

  final String totalDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.slate200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InrAmountText(
                  totalDisplay,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Payable',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VendorPayableTile extends StatelessWidget {
  const VendorPayableTile({
    super.key,
    required this.group,
    required this.onTap,
  });

  final VendorPayableGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                group.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            InrAmountText(
              group.pendingDisplay,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorsEmptyState extends StatelessWidget {
  const VendorsEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<double?> showRecordPaymentSheet({
  required BuildContext context,
  required VendorBill bill,
}) {
  return showBulkPaymentSheet(
    context: context,
    title: 'Pay ${bill.vendor}',
    subtitle: bill.stkNo,
    selectedTotal: bill.pendingAmount,
    selectedTotalDisplay: bill.pendingDisplay,
  );
}

Future<double?> showBulkPaymentSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required double selectedTotal,
  required String selectedTotalDisplay,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BulkPaymentSheet(
      title: title,
      subtitle: subtitle,
      selectedTotal: selectedTotal,
      selectedTotalDisplay: selectedTotalDisplay,
    ),
  );
}

class _BulkPaymentSheet extends StatefulWidget {
  const _BulkPaymentSheet({
    required this.title,
    required this.subtitle,
    required this.selectedTotal,
    required this.selectedTotalDisplay,
  });

  final String title;
  final String subtitle;
  final double selectedTotal;
  final String selectedTotalDisplay;

  @override
  State<_BulkPaymentSheet> createState() => _BulkPaymentSheetState();
}

class _BulkPaymentSheetState extends State<_BulkPaymentSheet> {
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.selectedTotal.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);

    if (amount == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amount < 0.01) {
      setState(() => _error = 'Minimum is 0.01');
      return;
    }
    if (amount > widget.selectedTotal + 0.001) {
      setState(() {
        _error = 'Cannot exceed ${widget.selectedTotalDisplay}';
      });
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + media.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rs. ',
                helperText: 'Selected total Rs. ${widget.selectedTotalDisplay}',
                errorText: _error,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
  }
}
