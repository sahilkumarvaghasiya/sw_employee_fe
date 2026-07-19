import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
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
                  'Pay Vendor',
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

/// Search bar shown above the total card on the Pay Vendor hub.
class VendorsSearchBar extends StatelessWidget {
  const VendorsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;

        return SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search vendor',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Clear search',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? colorScheme.surface : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.slate200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
            ),
          ),
        );
      },
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

enum StatementEntryKind { purchase, payment, discount }

class StatementEntryTile extends StatelessWidget {
  const StatementEntryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountDisplay,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final String amountDisplay;
  final StatementEntryKind kind;

  Color get _amountColor {
    switch (kind) {
      case StatementEntryKind.purchase:
        return AppColors.emerald;
      case StatementEntryKind.payment:
      case StatementEntryKind.discount:
        return const Color(0xFFC2410C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InrAmountText(
            amountDisplay,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showPaymentReceiptSheet({
  required BuildContext context,
  required String vendorName,
  required String amountDisplay,
  required List<VendorBill> bills,
  double discount = 0,
  double surcharge = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaymentReceiptSheet(
      vendorName: vendorName,
      amountDisplay: amountDisplay,
      bills: bills,
      discount: discount,
      surcharge: surcharge,
    ),
  );
}

class _PaymentReceiptSheet extends StatelessWidget {
  const _PaymentReceiptSheet({
    required this.vendorName,
    required this.amountDisplay,
    required this.bills,
    this.discount = 0,
    this.surcharge = 0,
  });

  final String vendorName;
  final String amountDisplay;
  final List<VendorBill> bills;
  final double discount;
  final double surcharge;

  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment recorded',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Just now',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                InrAmountText(
                  amountDisplay,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Payment',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vendorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Paid for',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.28),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bills.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Purchase#${bill.stkNo}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          bill.billDate,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InrAmountText(
                          bill.pendingDisplay,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (discount > 0 || surcharge > 0) ...[
              const SizedBox(height: 8),
              if (discount > 0)
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    const Text('Discount'),
                    const Spacer(),
                    Text(
                      '(-)${_inr.format(discount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              if (surcharge > 0)
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    const Text('Surcharge'),
                    const Spacer(),
                    Text(
                      '(+)${_inr.format(surcharge)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
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
